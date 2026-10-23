require "test_helper"

# The classifier's local reader, as Ruby asks it: settings, the weights'
# digest, and one request against a socket standing in for the sidecar.
class PointerClassifierAgentTest < ActiveSupport::TestCase
  test "no address or no weights is not set up, and a request says so without sending" do
    assert_not_predicate PointerClassifierAgent, :configured?, "the suite runs with no reader"
    error = assert_raises(PointerClassifierAgent::Unavailable) do
      PointerClassifierAgent.new(endpoint: nil, model: "pointer-x").ask_questions(state: {}, questions: { "intent" => {} })
    end
    assert_match(/not set up/, error.message)
  end

  test "the weights are named by the digest of pointer.pt, and missing files are named" do
    Dir.mktmpdir do |weights|
      with_weights(weights) do
        assert_nil PointerClassifierAgent.model
        assert_equal PointerClassifierAgent::WEIGHT_FILES, PointerClassifierAgent.missing_weights

        File.binwrite(File.join(weights, "pointer.pt"), "weights")
        assert_equal "pointer-#{Digest::SHA256.hexdigest("weights").first(16)}", PointerClassifierAgent.model
        assert_not_includes PointerClassifierAgent.missing_weights, "pointer.pt"
      end
    end
  end

  test "a request posts System One's body and reads the answer, and an error or a 503 is unavailable" do
    replies = Queue.new
    posted = Queue.new
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      loop do
        client = server.accept
        head = +""
        head << client.gets until head.end_with?("\r\n\r\n")
        posted << JSON.parse(client.read(head[/content-length: (\d+)/i, 1].to_i))
        status, body = replies.pop
        client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
        client.close
      end
    end
    agent = PointerClassifierAgent.new(endpoint: "http://127.0.0.1:#{server.addr[1]}/", model: "pointer-abc")

    replies << [ "200 OK", { answers: { intent: { type: "choice", choice: "take" } }, usage: { cost: 0 } }.to_json ]
    body = agent.ask_questions(state: { "player_action" => "take it" }, questions: { "intent" => { "type" => "choice" } })
    assert_equal "take", body.dig("answers", "intent", "choice")
    assert_equal({ "model" => "pointer-abc", "state" => { "player_action" => "take it" },
                   "questions" => { "intent" => { "type" => "choice" } } }, posted.pop)

    replies << [ "503 Service Unavailable", { error: "the model is still loading" }.to_json ]
    assert_raises(PointerClassifierAgent::Unavailable) { agent.ask_questions(state: {}, questions: { "intent" => {} }) }
    replies << [ "200 OK", { error: "not trained" }.to_json ]
    assert_raises(PointerClassifierAgent::Unavailable) { agent.ask_questions(state: {}, questions: { "intent" => {} }) }
  ensure
    thread&.kill
    server&.close
  end

  private

  def with_weights(path)
    ENV["POINTER_CLASSIFIER_WEIGHTS"] = path
    yield
  ensure
    ENV.delete("POINTER_CLASSIFIER_WEIGHTS")
  end
end
