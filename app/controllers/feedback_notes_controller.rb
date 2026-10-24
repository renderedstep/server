require "open3"
require "shellwords"

# A NOTE TO THE MAINTAINER, typed into a small dialog off the top of any page
# and handed to a local command named by `FEEDBACK_COMMAND`.
#
# Not `FeedbacksController`, which records a verdict on one turn as evaluation
# data. This is a free note about the app, and it leaves the app: nothing is
# written to the database.
#
# NO SHELL. The variable is split into a fixed argument array once, the request
# id and `--json -` are appended as further arguments, and the note goes on the
# command's stdin. Shell metacharacters in the variable stay literal arguments.
#
# WHAT IS SENT, AND NOTHING ELSE: the typed text, the screen as
# `controller#action`, and on a game screen the current room's name and the
# playthrough's id, then a "Device:" block of what the browser reports about
# itself (`DEVICE_FIELDS`, each checked and capped). No narration, no transcript, no token, no other game. The
# screen is checked against the routes and the playthrough is looked up here, so
# the page cannot put anything else in the message.
#
# A SENT NOTE IS A COMMAND THAT EXITED 0. Anything else -- a non-zero exit, a
# command that is not there -- is reported as a failure, never as "Sent".
#
# GATED TWICE. Absent and 404 unless `FEEDBACK_COMMAND` is set, and absent and
# 404 unless `Playthrough::Debug.enabled?` -- the app's one answer to "is the
# person at this keyboard the one building the game" (see `FeedbacksController`),
# so a player handed a playthrough link is not shown it.
class FeedbackNotesController < ApplicationController
  MAX_LENGTH = 2000
  NOTES_PER_MINUTE = 5
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  # WHAT THE BROWSER SAYS ABOUT THE DEVICE, filled in by the dialog's script as
  # the note is sent. Each value is kept only if it matches its pattern, and the
  # free one -- the user agent -- is capped; anything else is dropped, never
  # passed on. The label is what the "Device:" block calls it.
  DEVICE_FIELDS = {
    user_agent: [ "Browser", /\A[[:print:]]{1,300}\z/ ],
    screen: [ "Screen", /\A\d{1,5}x\d{1,5}\z/ ],
    viewport: [ "Viewport", /\A\d{1,5}x\d{1,5}\z/ ],
    visual_viewport: [ "Visual viewport", /\A\d{1,5}x\d{1,5}\z/ ],
    pixel_ratio: [ "Pixel ratio", /\A\d{1,2}(\.\d{1,4})?\z/ ],
    standalone: [ "Home screen app", /\A(true|false)\z/ ],
    color_scheme: [ "Colour scheme", /\A(light|dark)\z/ ]
  }.freeze

  # One store for the process, as `Api::V1::TurnsController` has, so the limit
  # holds in the test environment whose cache stores nothing.
  RATE_STORE = ActiveSupport::Cache::MemoryStore.new

  before_action :require_enabled
  rate_limit to: NOTES_PER_MINUTE, within: 1.minute, only: :create, store: RATE_STORE,
             with: -> { reject }

  # The configured command as an argument array, or nil when there is none.
  def self.command
    value = ENV.fetch("FEEDBACK_COMMAND", "")
    value.strip.empty? ? nil : Shellwords.split(value)
  end

  def self.enabled? = command.present? && Playthrough::Debug.enabled?

  def self.screens
    @screens ||= Rails.application.routes.routes.filter_map do |route|
      controller, action = route.defaults.values_at(:controller, :action)
      "#{controller}##{action}" if controller && action
    end.to_set
  end

  # The message on the command's stdin.
  def self.body(text:, screen:, playthrough: nil, device: {})
    lines = [ "Text adventure feedback (screen: #{screen})" ]
    if playthrough
      lines << "Playthrough: #{playthrough.id}"
      lines << "Room: #{playthrough.current_location.name}" if playthrough.current_location
    end
    note = "#{lines.join("\n")}\n\n#{text}\n"
    return note if device.empty?

    "#{note}\nDevice:\n#{device.map { |field, value| "#{DEVICE_FIELDS[field].first}: #{value}" }.join("\n")}\n"
  end

  # The device fields that pass their pattern, in `DEVICE_FIELDS` order.
  def self.device(params)
    DEVICE_FIELDS.each_with_object({}) do |(field, (_label, pattern)), kept|
      value = params&.[](field).to_s.strip
      kept[field] = value if value.match?(pattern)
    end
  end

  def create
    text = params[:text].to_s.strip
    screen = params[:screen].to_s
    request_id = params[:request_id].to_s

    valid?(text, screen, request_id) && sent?(text, screen, request_id) ? accept : reject
  end

  private

  def require_enabled
    head :not_found unless self.class.enabled?
  end

  def valid?(text, screen, request_id)
    text.present? && text.length <= MAX_LENGTH &&
      self.class.screens.include?(screen) && request_id.match?(UUID_FORMAT)
  end

  def playthrough
    Playthrough.find_by(id: params[:playthrough_id]) if params[:playthrough_id].present?
  end

  def sent?(text, screen, request_id)
    device = self.class.device(params[:device].is_a?(ActionController::Parameters) ? params[:device] : nil)
    body = self.class.body(text: text, screen: screen, playthrough: playthrough, device: device)
    _output, status = Open3.capture2e(*self.class.command, "--request-id", "ta-feedback-#{request_id}", "--json", "-",
                                      stdin_data: body)
    status.success?
  rescue SystemCallError
    false
  end

  # A fresh form, closed, with the confirmation beside the button.
  def accept
    render turbo_stream: turbo_stream.replace("feedback", partial: "feedback_notes/feedback",
                                                          locals: { screen: params[:screen].to_s,
                                                                    playthrough_id: params[:playthrough_id],
                                                                    status: :sent })
  end

  # Leaves the dialog open with the typed text in it, and says so inside it.
  def reject
    render turbo_stream: turbo_stream.replace("feedback_status", partial: "feedback_notes/status",
                                                                 locals: { status: :failed }),
           status: :unprocessable_content
  end
end
