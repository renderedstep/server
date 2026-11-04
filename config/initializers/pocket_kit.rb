# A NOTE TO THE MAINTAINER, typed into a small dialog off the top of any page
# and handed to the local command named by `FEEDBACK_COMMAND`. The button, the
# endpoint (mounted in config/routes.rb), the device block and the no-shell
# command run are pocket-kit's; what is configured here is what belongs to this
# app. Not `FeedbacksController`, which records a verdict on one turn as
# evaluation data: this is a free note about the app, and it leaves the app --
# nothing is written to the database.
#
# GATED TWICE. Absent and 404 unless `FEEDBACK_COMMAND` is set, and absent and
# 404 unless `Playthrough::Debug.enabled?` -- the app's one answer to "is the
# person at this keyboard the one building the game" -- so a player handed a
# playthrough link is not shown it.
#
# ON A GAME SCREEN the playthrough's id rides with the form and the room is
# looked up here, so the page cannot put anything else in the message: no
# narration, no transcript, no token, no other game.
#
# Exit 3 from the command means saved but not yet announced, which is sent.
PocketKit.configure do |config|
  config.feedback.command_env = "FEEDBACK_COMMAND"
  config.feedback.heading = "Text adventure feedback"
  config.feedback.request_id_prefix = "ta-feedback"
  config.feedback.sent_exit_codes = [ 0, 3 ]
  config.feedback.enabled = ->(_controller) { Playthrough::Debug.enabled? }
  config.feedback.hidden_fields = [ :playthrough_id ]
  config.feedback.context_lines = lambda do |controller|
    id = controller.params[:playthrough_id]
    playthrough = Playthrough.find_by(id: id) if id.is_a?(String) && id.present?
    next [] unless playthrough

    [ "Playthrough: #{playthrough.id}", *("Room: #{playthrough.current_location.name}" if playthrough.current_location) ]
  end

  # AN ERROR REPORT, handed as pocket-kit's JSON report to the local command
  # named by `ERRORS_COMMAND`: a request that ends in a 500, an exception that
  # escapes a job (NarrationJob's included), and an uncaught error or unhandled
  # rejection on the page, which app/javascript/application.js loads the
  # catcher for. Repeats are grouped by pocket-kit and sent once a window.
  #
  # OFF UNLESS `ERRORS_COMMAND` IS SET: no meta tag, a 404 for the page's post,
  # and nothing done for a request or a job. A report is run on pocket-kit's
  # own background thread, so it never holds up or fails the request or job
  # that raised, and nothing it does is read by the game or a model.
  #
  # Not gated on `Playthrough::Debug.enabled?` as the button is: a player's
  # page error is the one the owner most needs to hear about, and the page
  # posts only an error's class, message, stack and path -- no game text.
  config.errors.command_env = "ERRORS_COMMAND"
  config.errors.heading = "Text adventure"
  config.errors.request_id_prefix = "ta-errors"
  config.errors.sent_exit_codes = [ 0, 3 ]

  # A SESSION REPLAY -- about the last 30 seconds of the page, held in memory
  # by pocket-kit's rrweb recorder -- rides with a feedback note or a page
  # error report, and with nothing else. The layout's pocket_kit_replay_tag is
  # absent wherever neither of the two above could send, so with no command
  # set nothing is recorded. Typed text stays masked (`show_typed_text` is
  # left false): rrweb masks every input, textarea and select, and the views
  # that echo a typed line back (`.command`, the saved-turn notice) carry
  # `rr-mask` so the line is not recorded in clear there either. Narration
  # that restates what the player did is game prose and is recorded.
  config.replay.enabled = true
end
