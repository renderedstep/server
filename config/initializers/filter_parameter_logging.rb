# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# THE LINE A PLAYER TYPED, by its exact name in each front end: `command` in
# the browser's turn form, `line` in the engine API. A free-typed line the
# reader refuses is kept for the owner alone (`RefusedLine`), so the request
# log must not keep a second copy of it. Matched whole, so a parameter that
# only contains the word is left alone.
Rails.application.config.filter_parameters += [ /\Acommand\z/, /\Aline\z/ ]
