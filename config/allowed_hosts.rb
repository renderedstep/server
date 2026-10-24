# Which Host headers production answers, read from RAILS_ALLOWED_HOSTS.
#
# Set it (comma-separated) when the app sits behind a proxy on loopback — the
# private install in docs/local-deploy.md sets the tailnet name — and requests
# for any other host are refused. Leave it unset and every host is answered,
# as before, so a deploy that never set it does not change on upgrade.
#
# /up is always exempt, so a health check on 127.0.0.1 passes whatever the list.
module AllowedHosts
  HEALTH_CHECK = ->(request) { request.path == "/up" }

  # The hosts to append to config.hosts, or [] to leave host checking off.
  def self.parse(value)
    value.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def self.apply(config, value = ENV["RAILS_ALLOWED_HOSTS"])
    hosts = parse(value)
    return if hosts.empty?

    config.hosts.concat(hosts)
    config.host_authorization = { exclude: HEALTH_CHECK }
  end
end
