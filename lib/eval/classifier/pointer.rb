# A SMALL LOCAL MODEL IN SYSTEM ONE'S SEAT, MEASURED ON THE SAME BENCH.
#
# Stage 1 of replacing the classifier's System One call with a model that runs
# on this machine (and later on an FPGA): an encoder of about 17M parameters
# with a POINTER HEAD, reading a compact form of the cascade request's `state`
# and answering its questions in Jev's own answer shape. The design and the
# reasons for it are in the stage's scout report; what matters here is the
# contract, which is the standing one for every model in this app:
#
#   * IT ONLY PICKS FROM THE ENGINE'S OWN LIST. Each target answer is a score
#     per record the question offered, plus `nothing`, softmaxed over exactly
#     those keys -- an index into the engine's list, so it cannot name a
#     record that is not there. The engine's answer check
#     (`cascade::Answers`) still runs on every answer, unchanged.
#   * NOTHING IS TRUSTED MORE THAN JEV IS. The answers go back through the
#     engine's own `compose`, with its thresholds, exactly as Jev's do.
#
# WHAT RUNS WHERE. The model is PyTorch, so it runs as a child process
# (`script/pointer_classifier/serve.py`) that reads one request per line on
# stdin and writes one answer per line on stdout. This class owns that
# process. The weights, the training data and every run's output live outside
# the repository, in a directory the arm names (`MODELS=pointer:<dir>`); the
# repository holds only the code that builds, trains and asks the model.
#
# ESCALATION, WITH NO KEY. A live cascade sends a line on to Mistral when
# `named_more_than_one` >= 0.5 or `target_present` < 0.15. A local arm must run
# with no key and spend nothing, so it answers that call itself, with the
# reading the engine would have composed with escalation OFF
# (`cascade::compose`, `Escalation::Off`): the chosen intent, a reported move
# opened by a speaking verb read as talk, and the target and second name only
# while `target_present` is at or above the gate. The line still records
# `typed_model_escalated`, so the board's resolver counts say how many lines
# a live turn would have sent to Mistral. The figure this arm reports is
# therefore the local model ALONE, which is what stage 1 is asked for; the
# local model plus a paid escalation is a different arm.
class Eval::Classifier::Pointer
  SCRIPT = Rails.root.join("script/pointer_classifier/serve.py")

  # `cascade::PRESENCE_THRESHOLD` and `cascade::SPEECH_VERBS` in the engine,
  # restated because the escalated call has to be answered the way the
  # engine's own composition would have read it, and the engine composes
  # nothing once it has escalated.
  PRESENCE_THRESHOLD = 0.15
  SPEECH_VERBS = %w[tell ask say shout yell whisper warn inform remind promise].freeze

  # Which Python runs the model. The default is the virtualenv the training
  # set-up makes beside the weights; `POINTER_PYTHON` names another.
  def self.python_for(directory)
    ENV["POINTER_PYTHON"].presence || Pathname.new(directory).join("..", "venv", "bin", "python").to_s
  end

  class Unavailable < StandardError; end

  attr_reader :directory, :precision

  def initialize(directory:, precision: "fp32", threads: 1)
    @directory = Pathname.new(directory).expand_path
    @precision = precision.to_s
    @threads = threads
    @mutex = Mutex.new
  end

  # One cascade request, answered: Jev's body shape, `{answers: {id => ...}}`.
  def answer(state, questions)
    options = questions.to_h { |id, question| [ id, question["type"] == "noul" ? nil : question.fetch("criteria").keys ] }
    ask({ "state" => state, "questions" => options })
  end

  def close
    @mutex.synchronize do
      return unless @stdin

      @stdin.close
      @thread.value
      @stdin = @stdout = @thread = nil
    end
  end

  # The classifier call's answer for a line whose System One reading the
  # engine escalated: see ESCALATION above. `state` and `body` are what this
  # line was just asked and answered; `user` is the classifier request's
  # prompt, read only for the token each physical attempt is listed under.
  def self.escalated_reading(state, body, user)
    answers = body.fetch("answers")
    action = answers.dig("intent", "choice").to_s
    action = "talk" if action == "move" && spoken?(state["player_action"].to_s)
    present = answers.dig("target_present", "noul").to_f >= PRESENCE_THRESHOLD
    records = records_of(state)
    target_key = present ? answers.dig("target_#{action}", "choice") : nil
    target = records[target_key]
    also_key = present ? answers.dig("also_named", "choice") : nil
    also = records[also_key]
    also = nil if also.nil? || also_key == target_key || !Array(also["valid_intents"]).include?(action)

    { "intent" => action, "target" => name_for(target, user), "also_named" => name_for(also, user),
      "thrown_at" => "nothing" }
  end

  def self.spoken?(line)
    first = line.downcase.split(/[^[:alnum:]]+/).find(&:present?)
    SPEECH_VERBS.include?(first)
  end

  def self.records_of(state)
    %w[ways_out other_characters available_items player_items physical_actions]
      .flat_map { |group| state.fetch(group, {}).to_a }.to_h
  end

  # A record as the classifier's schema names it: its name, or, for a
  # physical attempt, the token the prompt lists it under.
  def self.name_for(record, user)
    return "nothing" if record.nil?
    return record.fetch("name") unless record["kind"] == "one complete physical action attempt"

    listed = user.to_s.lines.map(&:strip).find { |row| row.end_with?(": #{record.fetch("name")}") }
    listed ? listed.delete_suffix(": #{record.fetch("name")}") : "nothing"
  end

  private

  def ask(request)
    @mutex.synchronize do
      start! unless @stdin
      @stdin.puts(JSON.generate(request))
      @stdin.flush
      line = @stdout.gets or raise Unavailable, "the pointer model's process exited: #{@stderr_tail.join}"
      reply = JSON.parse(line)
      raise Unavailable, reply.fetch("error") if reply.key?("error")

      reply
    end
  end

  def start!
    python = self.class.python_for(directory)
    raise Unavailable, "no Python at #{python}; set POINTER_PYTHON" unless File.executable?(python)

    environment = { "OMP_NUM_THREADS" => @threads.to_s, "TOKENIZERS_PARALLELISM" => "false",
                    "HF_HUB_OFFLINE" => "1" }
    @stdin, @stdout, stderr, @thread = Open3.popen3(environment, python, SCRIPT.to_s, directory.to_s,
                                                     "--precision", precision, "--threads", @threads.to_s)
    @stderr_tail = []
    Thread.new { stderr.each_line { |row| (@stderr_tail << row).shift while @stderr_tail.size > 20 } }
    ready = @stdout.gets or raise Unavailable, "the pointer model did not start: #{@stderr_tail.join}"
    raise Unavailable, "the pointer model did not start: #{ready}" unless JSON.parse(ready)["ready"]
  end
end
