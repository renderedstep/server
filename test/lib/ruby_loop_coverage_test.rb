require "test_helper"

# THE LEDGER OF WHAT HOLDS THE RUST ENGINE TO EACH RUBY-LOOP TEST.
#
# `test/ruby_loop_coverage.yml` names, for every test of the Ruby turn loop,
# the check that holds the Rust engine to the same behaviour: a sweep step's
# expectation, a golden or a records file the engine reproduces, a vector
# portion, a Rust test at the pinned engine commit, or a test here that plays
# the engine. The loop's tests go when the loop does, and this is what makes
# that safe to do: a test deleted from a mapped file must have left behind a
# counterpart, or the reason none is needed.
#
# An entry is a test name in a mapped file, with:
#
#   pins:     the behaviour, in one line
#   by:       its counterparts, each "<kind> <reference>":
#               sweep   <script>#<step>      that step's `expect:`
#               golden  <script>#<step>      that step's golden dump
#               record  <script>#<step>      that step's engine records file
#             where a step is its id, or its number for a step with no id,
#             and a script named alone is every step of it
#               vector  <portion>            every case of the portion
#               rust    <path>::<function>   a test at the pinned engine
#               server  <path>::<test name>  a test here that plays the engine
#   partial:  what the counterparts leave weaker than the Ruby test held
#   obsolete: why no counterpart is needed -- the test holds Ruby plumbing,
#             or a guard no turn can reach on the engine
#   open:     a behaviour nothing holds the engine to yet; such a test must
#             not be deleted
#   stays:    the test is not the loop's, and outlives it
class RubyLoopCoverageTest < ActiveSupport::TestCase
  MAP = Rails.root.join("test/ruby_loop_coverage.yml")
  KINDS = %w[sweep golden record vector rust server].freeze
  VERDICTS = %w[by obsolete open stays].freeze

  def self.map = @map ||= YAML.safe_load_file(MAP)

  # Every `test "..."` of a file, as written: a name with interpolation is
  # its source between the quotes.
  def self.tests_in(path)
    names = []
    visit = lambda do |node|
      next unless node.is_a?(Prism::Node)

      if node.is_a?(Prism::CallNode) && node.receiver.nil? && node.name == :test && node.block
        name = node.arguments&.arguments&.first
        names << (name.is_a?(Prism::StringNode) ? name.unescaped : name.slice[1...-1])
      end
      node.compact_child_nodes.each { |child| visit.call(child) }
    end
    visit.call(Prism.parse_file(path.to_s).value)
    names
  end

  def entries = self.class.map.flat_map { |file, tests| tests.map { |name, entry| [ file, name, entry ] } }

  test "every test of a mapped file is in the map, and every entry says one thing about it" do
    problems = self.class.map.flat_map do |file, tests|
      path = Rails.root.join(file)
      unmapped = path.exist? ? self.class.tests_in(path) - tests.keys : []
      unmapped.map { |name| "#{file}: #{name.inspect} is not in the map" } +
        tests.filter_map do |name, entry|
          verdicts = entry.keys & VERDICTS
          "#{file}: #{name.inspect} says #{verdicts.inspect}; exactly one of #{VERDICTS.join(", ")}" unless verdicts.size == 1
        end
    end

    assert_empty problems, problems.join("\n")
  end

  # A TEST MAY GO ONLY WITH ITS COUNTERPART NAMED. An entry whose test is no
  # longer in its file is a test that was deleted, and only a counterpart or
  # the reason none is needed makes that safe.
  test "no test is gone from a mapped file without a counterpart" do
    problems = entries.filter_map do |file, name, entry|
      path = Rails.root.join(file)
      next if path.exist? && self.class.tests_in(path).include?(name)
      next if entry.key?("by") || entry.key?("obsolete")

      "#{file}: #{name.inspect} is gone, and its entry says #{(entry.keys & VERDICTS).inspect}"
    end

    assert_empty problems, problems.join("\n")
  end

  test "every counterpart named is there" do
    source = EngineSweep::Vendored.source
    problems = entries.flat_map do |file, name, entry|
      Array(entry["by"]).filter_map { |counterpart| missing(counterpart, source)&.then { |why| "#{file}: #{name.inspect}: #{counterpart} -- #{why}" } }
    end

    assert_empty problems, problems.join("\n")
  end

  private

  def missing(counterpart, source)
    kind, reference = counterpart.to_s.split(" ", 2)
    return "not one of #{KINDS.join(", ")}" unless KINDS.include?(kind) && reference.present?

    case kind
    when "sweep", "golden", "record" then missing_step(kind, reference, source)
    when "vector" then "no such portion" unless Rails.root.join(EngineVectors::DIRECTORY, "#{reference}.json").exist?
    when "rust" then missing_function(reference, source)
    when "server" then missing_test(reference)
    end
  end

  def missing_step(kind, reference, source)
    script, step = reference.split("#", 2)
    path = EngineSweep::DIRECTORY.join("#{script}.yml")
    return "no such script" unless path.exist?

    found = step.nil? || EngineSweep::Script.load(path).steps.any? { |candidate| [ candidate.id, candidate.index.to_s ].include?(step) }
    return "no step #{step.inspect}" unless found

    case kind
    when "golden" then "no golden" unless Rails.root.join(EngineSweep::Parity::DIRECTORY, "#{script}.json").exist?
    when "record"
      records = source.join("parity/records/#{script}.json")
      return "the engine keeps no records of it" unless records.exist?

      labels = JSON.parse(records.read).fetch("steps").map { |row| row["step"].to_s.split(" ") }
      "no records of that step" unless step.nil? || labels.any? { |label| [ label[1], label[2] ].include?(step) }
    end
  end

  def missing_function(reference, source)
    path, function = reference.split("::", 2)
    file = source.join(path)
    return "the pinned engine has no #{path}" unless file.exist?

    "the pinned engine's #{path} has no fn #{function}" unless file.read.match?(/\bfn #{Regexp.escape(function.to_s)}\b/)
  end

  def missing_test(reference)
    path, name = reference.split("::", 2)
    file = Rails.root.join(path)
    return "no such file" unless file.exist?

    "no such test" unless self.class.tests_in(file).include?(name)
  end
end
