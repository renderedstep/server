# The classifier's own reader: the small pointer model, answering the
# classifier's typed questions from a process on this machine.
#
# WHAT IT IS. The engine reads every free-typed line through this reader and
# through nothing else (`renderedstep_engine::classifier::read_locally`): a
# line it is sure of is played as `typed_model`, a target it reads as absent is
# refused with the list of what is here, and a free-typed throw is not asked
# at all and is pointed at `/throw`. The model call (Mistral) is never made
# for a free-typed line. A slashed line is read by the grammar first and asks
# nothing.
#
# AN UNSURE LINE IS ASKED ABOUT, NOT PLAYED -- the owner's ruling of
# 2026-10-29, "always refuse and ask". The reader answers every choice with how
# sure it is of each option, and below 0.9 (the engine's
# `cascade::CONFIDENCE_FLOOR`) on the act or on the thing for it, the line is
# refused as `unsure` and the player is shown its best guess as a slash line to
# type. That is what `typed_model_unsure` now means, and all it means: a
# refused line writes no scene, so the value is in the turn's journal and in
# the kept line (`RefusedLine`), never on a `Scene`. A reply with no
# probability for its own pick counts as unsure; the sidecar always sends one.
# The 0.9 is a round number, to be checked against the kept lines before it
# changes.
#
# WHERE IT RUNS. The model is PyTorch, so it is a sidecar process
# (`script/pointer_classifier/serve.py --http`, started by `bin/pointer-classifier`
# as the `classifier` line of `Procfile.dev`) that answers System One's own
# body, `{model, state, questions}`, at `POINTER_CLASSIFIER_URL`. It costs
# nothing and takes no key. The engine posts to it itself on every turn
# (`Playthrough::RustEngine.models`); this class is the Ruby side of the same
# reader, for the bench and for anything that needs to know whether it is
# set up.
#
# THE ADDRESS IS THE SWITCH, AND THERE IS NO FALLBACK. With no address, or no
# weights to name, the reader is not set up, and the engine refuses every
# free-typed line with a pointer to the slash commands (`typed_model_down`)
# and says so on stderr. It never quietly hands the line to Mistral instead:
# that would bring a second reader back in disguise, and anything measured
# would be measured on a different model. The System One keys
# (`SystemOneAgent`) switch Jev for speech, bystander acts and arrival only.
#
# THE WEIGHTS ARE NOT IN THE REPOSITORY. They live in a directory this
# checkout names (`POINTER_CLASSIFIER_WEIGHTS`), fetched from a public
# release by `bin/update`'s `pointer_reader` step, which also says what is
# still missing and how to get it. Every request names them by digest
# (`.model`), and a kept line (`RefusedLine#weights`) keeps it, so a refused
# reading can be tied to the weights that made it. No receipt column holds it.
class PointerClassifierAgent
  # The sidecar's whole URL. Read here and by `bin/pointer-classifier`, which
  # binds its port; `bin/dev` sets it when it is not set.
  ENDPOINT_VARIABLE = "POINTER_CLASSIFIER_URL".freeze

  # The weights directory, and the Python that runs them.
  WEIGHTS_VARIABLE = "POINTER_CLASSIFIER_WEIGHTS".freeze
  PYTHON_VARIABLE = "POINTER_CLASSIFIER_PYTHON".freeze

  # Where a checkout keeps them unless told otherwise: `storage/` is ignored.
  DEFAULT_HOME = "storage/pointer_classifier".freeze

  # What a weights directory must hold. `checkpoint.pt` is training-resume
  # state and is never shipped.
  WEIGHT_FILES = %w[pointer.pt config.json tokenizer.json tokenizer_config.json].freeze

  # The engine's System One timeout, and this reader's too: a loaded model
  # answers in well under a second, and a turn does not wait on one that is
  # still loading (it answers 503 until it is ready).
  TIMEOUT = SystemOneAgent::TIMEOUT

  # Every way a request fails. The engine's own reader refuses the line; the
  # bench records the failure.
  class Unavailable < StandardError; end

  def self.endpoint = ENV[ENDPOINT_VARIABLE].presence

  def self.weights = Pathname(ENV[WEIGHTS_VARIABLE].presence || Rails.root.join(DEFAULT_HOME, "weights"))

  def self.python = Pathname(ENV[PYTHON_VARIABLE].presence || Rails.root.join(DEFAULT_HOME, "venv/bin/python"))

  # The weight files this checkout is missing, by name.
  def self.missing_weights = WEIGHT_FILES.reject { |file| weights.join(file).file? }

  # Whether a turn would read through it: an address, and weights to name.
  def self.configured? = endpoint.present? && model.present?

  # The weights' name in a request and on its receipt: `pointer-` and the
  # first sixteen hex digits of `pointer.pt`'s SHA-256. Nil without weights.
  # Read once per file, because the file is a quarter of a gigabyte.
  def self.model
    file = weights.join("pointer.pt")
    return unless file.file?

    stat = file.stat
    key = [ file.to_s, stat.size, stat.mtime.to_f ]
    @digests ||= {}
    @digests[key] ||= "pointer-#{Digest::SHA256.file(file).hexdigest.first(16)}"
  end

  def initialize(endpoint: self.class.endpoint, model: self.class.model)
    @endpoint = endpoint
    @model = model
  end

  attr_reader :model

  # One request of the engine's typed questions, answered with the sidecar's
  # body: `{answers: {id => ...}, usage: {cost: 0}}`. Raises `Unavailable` for
  # anything else, an error the sidecar answered included.
  def ask_questions(state:, questions:)
    raise Unavailable, "the local reader is not set up (#{ENDPOINT_VARIABLE}, #{WEIGHTS_VARIABLE})" if @endpoint.blank? || @model.blank?

    uri = URI(@endpoint)
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.post(uri.request_uri, { model: @model, state: state, questions: questions }.to_json,
                "Content-Type" => "application/json")
    end
    raise Unavailable, "the local reader answered #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    raise Unavailable, "the local reader answered #{body.class} rather than a body" unless body.is_a?(Hash)
    raise Unavailable, "the local reader answered an error: #{body["error"]}" if body.key?("error")

    body
  rescue JSON::ParserError => e
    raise Unavailable, "the local reader answered something that is not JSON (#{e.class})"
  rescue Unavailable
    raise
  rescue StandardError => e
    raise Unavailable, "#{e.class}: #{e.message}"
  end
end
