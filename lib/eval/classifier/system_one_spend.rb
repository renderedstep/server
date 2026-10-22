# WHAT A BENCH RUN'S SYSTEM ONE REQUESTS COST, BOOKED OFF THEIR OWN RECEIPTS,
# AND THE CAP THAT STOPS IT RATHER THAN EXCEEDS.
#
# A bench run is one rolled-back transaction a pass (`Eval::Classifier::Bench`
# `#run`), so the `SystemOneReceipt` rows its requests write are rolled back
# with everything else and nothing on disk says what the run cost. This books
# each answered request as it comes back, from the provider's own `usage`:
# OpenRouter Decisions' `usage.cost`, or TypeSafe direct's input tokens at its
# published rate (`Eval::VolitionProbe::TYPESAFE_USD_PER_INPUT_TOKEN`; output
# is not charged). A request whose answer carries neither is booked at
# `SystemOneReceipt::COST_PER_REQUEST_USD`, the app's own conservative
# estimate, and counted as estimated.
#
# THE CAP. Before a request is sent, the spend so far plus one reservation for
# every request already in flight and one for this one is compared with the
# cap; a request that could cross it is not sent (`Reached`). The reservation is
# the dearest request booked so far, or the stated estimate before there is
# one, so the cap holds with eight in flight. A request that fails after it was
# sent may still have been billed, so it is booked at the reservation too.
class Eval::Classifier::SystemOneSpend
  class Reached < StandardError; end

  REPORTED = "reported".freeze
  ESTIMATED = "estimated".freeze

  attr_reader :cap

  def initialize(cap: nil)
    @cap = cap&.to_f
    @mutex = Mutex.new
    @spent = 0.0
    @calls = 0
    @estimated = 0
    @in_flight = 0
    @dearest = nil
  end

  # What one answered request cost and where the figure came from.
  def self.cost_of(transport, usage)
    usage = usage.is_a?(Hash) ? usage : {}
    cost = usage["cost"]
    return [ cost.to_f, REPORTED ] if cost.is_a?(Numeric) && cost.finite? && cost >= 0

    tokens = usage["input_tokens"]
    if transport.to_s == "typesafe_direct" && tokens.is_a?(Integer) && tokens >= 0
      return [ tokens * Eval::VolitionProbe::TYPESAFE_USD_PER_INPUT_TOKEN, REPORTED ]
    end

    [ SystemOneReceipt::COST_PER_REQUEST_USD.to_f, ESTIMATED ]
  end

  # Sends the request the block makes, unless it could cross the cap, and books
  # what its answer says it cost. The block returns the provider's body.
  # Returns `[payload, receipt]`.
  def charge(transport)
    reserve!
    begin
      payload = yield
    rescue StandardError
      settle!(reservation, ESTIMATED)
      raise
    end

    usd, source = self.class.cost_of(transport, payload.is_a?(Hash) ? payload["usage"] : nil)
    settle!(usd, source)
    [ payload, { "transport" => transport.to_s, "usage" => payload.is_a?(Hash) ? payload["usage"] : nil,
                 "cost_usd" => usd.round(9), "cost_source" => source } ]
  end

  def spent = @mutex.synchronize { @spent }
  def calls = @mutex.synchronize { @calls }

  def to_h
    @mutex.synchronize { { calls: @calls, estimated: @estimated, spent_usd: @spent.round(9), cap_usd: @cap } }
  end

  private

  def reservation = @dearest || SystemOneReceipt::COST_PER_REQUEST_USD.to_f

  def reserve!
    @mutex.synchronize do
      if @cap && @spent + (@in_flight + 1) * reservation > @cap
        raise Reached, format("the System One cap of $%.4f is reached: $%.6f booked, %d in flight",
                              @cap, @spent, @in_flight)
      end

      @in_flight += 1
    end
  end

  def settle!(usd, source)
    @mutex.synchronize do
      @in_flight -= 1
      @spent += usd
      @calls += 1
      @estimated += 1 if source == ESTIMATED
      @dearest = usd if source == REPORTED && (@dearest.nil? || usd > @dearest)
    end
  end
end
