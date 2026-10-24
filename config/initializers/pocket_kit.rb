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
end
