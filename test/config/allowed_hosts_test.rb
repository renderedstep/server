require "test_helper"
require Rails.root.join("config/allowed_hosts").to_s

class AllowedHostsTest < ActiveSupport::TestCase
  Config = Struct.new(:hosts, :host_authorization)

  test "a comma-separated list is appended to the hosts and /up is exempt" do
    config = Config.new([], nil)
    AllowedHosts.apply(config, " omarchy.tailcdcf4d.ts.net, example.test ,")

    assert_equal %w[omarchy.tailcdcf4d.ts.net example.test], config.hosts
    exclude = config.host_authorization[:exclude]
    assert exclude.call(Struct.new(:path).new("/up"))
    assert_not exclude.call(Struct.new(:path).new("/"))
  end

  test "unset or blank leaves every host allowed" do
    [ nil, "", " , " ].each do |value|
      config = Config.new([], nil)
      AllowedHosts.apply(config, value)

      assert_empty config.hosts, "an empty hosts list means host checking is off"
      assert_nil config.host_authorization
    end
  end
end
