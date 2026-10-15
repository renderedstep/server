# WHAT ONE SYSTEM ONE REQUEST COST, because nothing else says.
#
# A chat leaves token receipts on `messages`, priced from the model registry.
# A System One request is not a chat (`SystemOneAgent`'s header): it has no
# message row and no token counts, and it cannot be switched off for one player
# -- a credential in the environment is the whole switch. Without a row of its
# own it would be spend no allowance could see, so every request writes one
# BEFORE it is sent, priced at `COST_PER_REQUEST_USD`, a stated constant, with
# `cost_source` "estimated". A request that fails after sending may still have
# been billed, so the row is never removed and keeps the estimate.
#
# WHEN THE PROVIDER REPORTS A PRICE, THE PRICE IS BOOKED, lower or higher than
# the estimate, and `cost_source` becomes "reported". OpenRouter Decisions
# reports `usage.cost`; TypeSafe direct reports tokens and no price, so its rows
# stay estimated rather than priced at a rate this app would be inventing. A
# reader telling real spend from the conservative figure reads `cost_source`.
#
# The Rust engine writes the rows a played turn leaves, under the same rule
# (renderedstep/engine `receipts::system_one_reported`); this class is the
# Ruby path's half and the two must agree.
#
# `latency_ms` is wall-clock from sending to the answer or the failure, kept
# whichever way the request went; a row written before it existed is NULL, not
# zero. `purpose` names the caller. The three volition calls are filed apart
# (`VOLITION_PURPOSES`); a row from before the split says only "volition", the
# combined form, and `.volition` reads all four as one family.
class SystemOneReceipt < ApplicationRecord
  CLASSIFIER = "classifier".freeze
  VOLITION_SPEECH = "volition_speech".freeze
  VOLITION_ACTS = "volition_acts".freeze
  VOLITION_REACTIONS = "volition_reactions".freeze
  VOLITION_PURPOSES = [ VOLITION_SPEECH, VOLITION_ACTS, VOLITION_REACTIONS ].freeze
  # What every volition row was filed under before the three were split.
  VOLITION_COMBINED = "volition".freeze

  # Stated, not measured: a round figure above what a classifier or volition
  # request has been seen to report, so an allowance errs towards refusing.
  # Booked only where no cost was reported.
  COST_PER_REQUEST_USD = BigDecimal("0.002")

  ESTIMATED = "estimated".freeze
  REPORTED = "reported".freeze
  COST_SOURCES = [ ESTIMATED, REPORTED ].freeze

  belongs_to :player, optional: true
  belongs_to :playthrough, optional: true

  validates :cost_usd, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_source, inclusion: { in: COST_SOURCES }
  validates :latency_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :volition, -> { where(purpose: [ *VOLITION_PURPOSES, VOLITION_COMBINED ]) }

  def self.record!(purpose:, transport:)
    create!(player: Current.player, playthrough: Current.playthrough, purpose: purpose,
            transport: transport&.to_s, cost_usd: COST_PER_REQUEST_USD, cost_source: ESTIMATED)
  end

  # Books the reported cost when it is a usable number (finite, not negative);
  # anything else leaves the estimate where it is.
  def reported!(usage)
    cost = usage.is_a?(Hash) ? usage["cost"] : nil
    return unless cost.is_a?(Numeric) && cost.finite? && cost >= 0

    update!(cost_usd: cost, cost_source: REPORTED)
  end

  def reported? = cost_source == REPORTED

  def took!(milliseconds) = update!(latency_ms: milliseconds)
end
