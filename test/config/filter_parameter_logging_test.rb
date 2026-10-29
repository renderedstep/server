require "test_helper"

# A typed line the reader refuses is kept for the owner alone (`RefusedLine`),
# so the request log does not keep it either, in either front end.
class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "the typed line is filtered from the log in the browser and in the engine API" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("command" => "approach Brace")["command"]
    assert_equal "[FILTERED]", filter.filter("line" => "approach Brace")["line"]
  end

  test "a parameter that only contains the word is not filtered" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "narrated", filter.filter("mode" => "narrated")["mode"]
    assert_equal "a1", filter.filter("commands_after" => "a1")["commands_after"]
  end
end
