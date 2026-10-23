# THE CLASSIFIER'S LOCAL READER NEEDS TWO THINGS THE REPOSITORY DOES NOT HOLD:
# a Python with CPU PyTorch, and the pointer model's weights
# (`PointerClassifierAgent`). Without them every free-typed line is refused,
# so this fetches the weights when they are missing and says what is still
# missing, and how to get it, on every run.
#
# THE WEIGHTS are a public release asset on renderedstep/server (`RELEASE`),
# so they download over plain HTTPS with no login and no key. This is the one
# step that opens the network, and it opens it only for a file that is
# missing: a directory that holds all four is never touched, whoever trained
# it. Each file is checked against the SHA-256 pinned in `DIGESTS` before it
# is moved into place, so a short read or a changed asset is refused, never
# loaded. Shipping a new model is a new release and new digests here. It makes
# no model call. The Python is a gigabyte and is not fetched: it is named.
class Update::Steps::PointerReader < Update::Step
  def self.key = :pointer_reader
  def self.reason = "give the classifier's local reader what the repository does not hold: its weights, fetched, and its Python, named"

  # The release the weights come from, and what each file must hash to.
  RELEASE = "https://github.com/renderedstep/server/releases/download/pointer-m68-step1".freeze
  DIGESTS = {
    "pointer.pt" => "032123780e5fb34ca26bceb8a979a1ca1979cce57132e3c5a9d026a536ebbda0",
    "config.json" => "bd3d3cd8afa746d97abae84df404c004a4a96de31fd49af20b9cb13fb5eeeb1e",
    "tokenizer.json" => "6c8aaa9a542084f2457eab775d4eeb51f92a70c0fd9de28d5edb0ddec3c08d30",
    "tokenizer_config.json" => "239885aa9c2ae7d31caf67e9a284f8741cb87846847a4ef74627efa3b6f33eb3"
  }.freeze

  # A GitHub asset answers with a redirect to its storage host.
  REDIRECTS = 5

  # `download` is how a file reaches disk: `(url, path)`, raising on failure.
  # A test hands one in; nothing else does.
  def initialize(download: nil, **)
    super(**)
    @download = download || method(:http_download)
  end

  def call
    agent = PointerClassifierAgent
    fetched, failure = fetch_missing(agent)
    lines = []
    lines << python_line(agent.python)
    lines << fetched_line(agent, fetched) if fetched.any?
    lines << weights_line(agent, failure)
    lines << "the address is #{agent.endpoint || "set by bin/dev (#{agent::ENDPOINT_VARIABLE})"}"
    report(changed: fetched.any?, lines: lines)
  end

  private

  # The files fetched (or, in a dry run, that would be), and why the rest
  # were not. A file that arrives with the wrong digest stops the run.
  def fetch_missing(agent)
    missing = agent.missing_weights
    return [ missing, nil ] if dry_run? || missing.empty?

    FileUtils.mkdir_p(agent.weights)
    fetched = []
    missing.each do |file|
      fetch(file, agent.weights.join(file))
      fetched << file
    rescue Update::StepFailed
      raise
    rescue StandardError => e
      return [ fetched, "#{file}: #{e.message}" ]
    end
    [ fetched, nil ]
  end

  def fetch(file, path)
    part = Pathname("#{path}.part")
    @download.call("#{RELEASE}/#{file}", part)
    digest = Digest::SHA256.file(part).hexdigest
    unless digest == DIGESTS.fetch(file)
      raise Update::StepFailed, "#{file} from #{RELEASE} hashes to #{digest}, not #{DIGESTS.fetch(file)}; it was not kept"
    end

    part.rename(path)
  ensure
    part&.delete if part&.exist?
  end

  def http_download(url, path, redirects = REDIRECTS)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        case response
        when Net::HTTPRedirection
          raise "too many redirects" if redirects.zero?

          return http_download(URI.join(url, response["location"]).to_s, path, redirects - 1)
        when Net::HTTPSuccess
          File.open(path, "wb") { |out| response.read_body { |chunk| out.write(chunk) } }
        else
          raise "#{url} answered #{response.code}"
        end
      end
    end
  end

  def python_line(python)
    return "Python: #{python}" if python.executable?

    "MISSING Python at #{python} -- make it with: uv venv --python 3.12 #{python.parent.parent} && " \
      "VIRTUAL_ENV=#{python.parent.parent} uv pip install --index-url https://download.pytorch.org/whl/cpu torch && " \
      "VIRTUAL_ENV=#{python.parent.parent} uv pip install -r script/pointer_classifier/requirements.txt " \
      "(or name another with #{PointerClassifierAgent::PYTHON_VARIABLE})"
  end

  def fetched_line(agent, files)
    "#{dry_run? ? "would fetch" : "fetched"} #{files.join(", ")} from #{RELEASE} into #{agent.weights}"
  end

  def weights_line(agent, failure)
    missing = agent.missing_weights
    return "weights: #{agent.model} at #{agent.weights}" if missing.empty?

    "MISSING weights at #{agent.weights} (#{missing.join(", ")})#{" -- the fetch failed: #{failure}" if failure} -- " \
      "download them from #{RELEASE} (#{agent::WEIGHT_FILES.join(", ")}; never checkpoint.pt), " \
      "or name another directory with #{agent::WEIGHTS_VARIABLE}. Until then every free-typed line is refused"
  end
end
