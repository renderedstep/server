# THE CLASSIFIER'S LOCAL READER NEEDS TWO THINGS THE REPOSITORY DOES NOT HOLD:
# a Python with CPU PyTorch, and the pointer model's weights
# (`PointerClassifierAgent`). Without them every free-typed line is refused,
# so this says which is missing and how to get it, on every run.
#
# It looks and never fetches: the weights are a private release asset, which
# needs the owner's access, and the Python is a gigabyte. Nothing here makes a
# model call or opens the network, and nothing is written, so it is
# `reports_only?` like the doctor.
class Update::Steps::PointerReader < Update::Step
  def self.key = :pointer_reader
  def self.reason = "check that the classifier's local reader can run: its Python and its weights, which the repository does not hold"
  def self.reports_only? = true

  def call
    agent = PointerClassifierAgent
    lines = []
    lines << python_line(agent.python)
    lines << weights_line(agent)
    lines << "the address is #{agent.endpoint || "set by bin/dev (#{agent::ENDPOINT_VARIABLE})"}"
    report(changed: false, lines: lines)
  end

  private

  def python_line(python)
    return "Python: #{python}" if python.executable?

    "MISSING Python at #{python} -- make it with: uv venv --python 3.12 #{python.parent.parent} && " \
      "VIRTUAL_ENV=#{python.parent.parent} uv pip install --index-url https://download.pytorch.org/whl/cpu torch && " \
      "VIRTUAL_ENV=#{python.parent.parent} uv pip install -r script/pointer_classifier/requirements.txt " \
      "(or name another with #{PointerClassifierAgent::PYTHON_VARIABLE})"
  end

  def weights_line(agent)
    missing = agent.missing_weights
    return "weights: #{agent.model} at #{agent.weights}" if missing.empty?

    "MISSING weights at #{agent.weights} (#{missing.join(", ")}) -- unpack the pointer model's release asset there " \
      "(#{agent::WEIGHT_FILES.join(", ")}; never checkpoint.pt), or name its directory with #{agent::WEIGHTS_VARIABLE}. " \
      "Until then every free-typed line is refused"
  end
end
