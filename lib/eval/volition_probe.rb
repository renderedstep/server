# WHAT ONE TYPED VOLITION CALL COSTS, MEASURED ON THE BYTES THE APP SENDS.
#
#   rake eval:volition_probe        spends: CALLS calls (default 4) under a CAP in USD
#   rake eval:volition_probe_price  free: the per-call price and a projection, from a kept set
#   rake eval:volition_baseline     spends: every staged room REPS times (default 4) under a CAP
#   rake eval:volition_baseline_summary  free: what a kept baseline set shows, recomputed
#
# THE BASELINE ROOMS are `test/fixtures/files/volition_baseline_requests.json`,
# twelve staged rooms that `Playthrough::Volition::BaselineRoomsTest` pins byte
# for byte against the app's own request, exactly as the single fixture above
# is pinned. Only the staged state differs room to room; the questions, and
# the pressure question's criteria, are the app's constants in every one.
# `ROOMS=speech` sends `volition_speech_baseline_requests.json` instead: the
# same rooms, with everybody who has something to say also asked what they
# say (the `:speech` question), which is the request an arrival sends.
#
# The request is `test/fixtures/files/volition_system_one_request.json` -- the
# staged Counting Room with Odile Vance in it. `Playthrough::Volition::RequestTest`
# pins that file byte for byte against what the engine's `volition` request
# builds, so sending the file is sending the app's request without a database.
#
# THE CEILING STOPS RATHER THAN EXCEEDS. Before each call the spend so far plus
# the dearest call seen so far is compared with CAP; a call that could cross it
# is not sent. The first call is priced by CAP alone, which is why CAP should
# sit well above one call.
#
# EVERY CALL LEAVES A PRICED RECEIPT, success or not: the provider's response
# id, `usage` (which carries `usage.cost`), and the answers; a failure keeps the
# status and the full error body and ends the run, because the transport the
# game uses deliberately logs only the status line. OpenRouter's credit reading
# is taken before and after, and the account may be shared, so the receipts'
# own `usage.cost` is the per-call figure and the credit delta is the bracket.
#
# TWO TRANSPORTS, AS THE GAME HAS: TypeSafe direct when `TYPESAFE_API_KEY` is
# present (`SystemOneAgent`'s own precedence), otherwise OpenRouter Decisions.
# Both send the same body and pin the same Jev release under its own name.
# TypeSafe reports tokens and not a price, so its receipt's `cost` is the
# input tokens at its published rate (`TYPESAFE_USD_PER_INPUT_TOKEN`; output
# is not charged), and there is no credit reading to bracket it with.
module Eval
  module VolitionProbe
    FIXTURE = Rails.root.join("test/fixtures/files/volition_system_one_request.json")
    ROOMS = Rails.root.join("test/fixtures/files/volition_baseline_requests.json")
    SPEECH_ROOMS = Rails.root.join("test/fixtures/files/volition_speech_baseline_requests.json")
    CREDITS = URI("https://openrouter.ai/api/v1/credits").freeze
    ROOT = Rails.root.join("db/eval")

    # docs.typesafe.ai/models: jev-1.13.0 at $0.042 per million input tokens.
    TYPESAFE_USD_PER_INPUT_TOKEN = 0.042 / 1_000_000

    # Where a run's calls go: its endpoint, the model name the body pins
    # there, its key, and whether it has a credit reading.
    Transport = Data.define(:name, :endpoint, :model, :key) do
      def typesafe? = name == "typesafe_direct"
    end

    module_function

    def transport
      if (key = ENV[SystemOneAgent::TYPESAFE_API_KEY_VARIABLE].presence)
        Transport.new(name: "typesafe_direct", endpoint: SystemOneAgent::TYPESAFE_ENDPOINT,
                      model: SystemOneAgent::TYPESAFE_MODEL, key: key)
      elsif (key = ENV["OPENROUTER_API_KEY"].presence)
        Transport.new(name: "openrouter_decisions", endpoint: SystemOneAgent::OPENROUTER_ENDPOINT,
                      model: SystemOneAgent::OPENROUTER_MODEL, key: key)
      else
        abort "neither TYPESAFE_API_KEY nor OPENROUTER_API_KEY is set"
      end
    end

    def run!(set:, calls:, cap:)
      request = JSON.parse(FIXTURE.read)
      via = transport
      body = { model: via.model, state: request["state"], questions: request["questions"] }
      send_all!(set: set, cap: cap, via: via, calls: Array.new(calls) { |index| [ { "call" => index + 1 }, body ] },
                kept: { "request_sha256" => Digest::SHA256.hexdigest(body.to_json) })
    end

    # EVERY ROOM, REPS TIMES, rooms in the file's order within each repetition
    # so a run stopped by the ceiling has spent evenly across the rooms.
    def run_rooms!(set:, reps:, cap:, rooms: ROOMS)
      file = rooms
      rooms = JSON.parse(file.read)
      via = transport
      calls = (1..reps).flat_map do |rep|
        rooms.map do |room|
          [ { "room" => room["room"], "rep" => rep },
            { model: via.model, state: room["state"], questions: room["questions"] } ]
        end
      end
      calls.each_with_index { |(label, _), index| label["call"] = index + 1 }
      dir = send_all!(set: set, cap: cap, via: via, calls: calls,
                      kept: { "requests_file" => file.relative_path_from(Rails.root).to_s,
                              "requests_sha256" => Digest::SHA256.file(file).hexdigest, "reps" => reps })
      # The set carries the bytes it was measured on, so its summary never
      # reads a fixture that may have moved since.
      FileUtils.cp(file, dir.join("requests.json"))
      dir
    end

    def send_all!(set:, cap:, calls:, kept:, via: transport)
      dir = ROOT.join(set)
      abort "#{dir} exists; a kept set is never written over" if dir.exist?

      receipts = []
      before = credits(via)
      spent = 0.0

      calls.each do |label, body|
        dearest = receipts.map { |r| r["cost"].to_f }.max || 0.0
        if spent + dearest > cap
          puts "stopped before call #{label["call"]}: #{spent.round(6)} spent + #{dearest} would cross #{cap}"
          break
        end

        receipt = label.merge(post(via, body))
        receipts << receipt
        spent += receipt["cost"].to_f
        puts "call #{label["call"]} #{label["room"]}: #{receipt["status"]} cost=#{receipt["cost"].inspect} spent=#{spent.round(6)}"
        break unless receipt["status"] == 200
        next if receipt["cost"].is_a?(Numeric)

        puts "stopped: call #{label["call"]} came back without usage.cost, so the ceiling cannot be kept"
        break
      end

      dir.mkpath
      File.write(dir.join("receipts.json"), "#{JSON.pretty_generate(
        "model" => via.model, "endpoint" => via.endpoint.to_s, "transport" => via.name,
        **kept, "cap_usd" => cap,
        "credits_before" => before, "credits_after" => credits(via), "receipts" => receipts
      )}\n")
      dir
    end

    # The figures a kept set supports, recomputed from its file alone.
    def price(set, project: 48)
      kept = JSON.parse(ROOT.join(set, "receipts.json").read)
      costs = kept["receipts"].select { |r| r["status"] == 200 }.map { |r| r["cost"].to_f }
      per_call = costs.empty? ? nil : costs.sum / costs.size
      { "calls" => kept["receipts"].size, "succeeded" => costs.size, "receipt_total" => costs.sum,
        "per_call" => per_call, "projected_calls" => project,
        "projected" => per_call && per_call * project,
        "credit_delta" => kept.dig("credits_after", "total_usage").to_f - kept.dig("credits_before", "total_usage").to_f }
    end

    def post(via, body)
      endpoint = via.endpoint
      http_request = Net::HTTP::Post.new(endpoint)
      http_request["Authorization"] = "Bearer #{via.key}"
      http_request["Content-Type"] = "application/json"
      http_request.body = body.to_json
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = Net::HTTP.start(endpoint.hostname, endpoint.port, use_ssl: true, read_timeout: 30) { |h| h.request(http_request) }
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)

      return { "status" => response.code.to_i, "seconds" => seconds, "error_body" => response.body } unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      { "status" => 200, "seconds" => seconds, "id" => payload["id"], "provider" => payload["provider"] || payload["model"],
        "usage" => payload["usage"], "cost" => cost_of(via, payload["usage"]), "answers" => payload["answers"] }
    end

    # What one answered call cost: OpenRouter's own `usage.cost`, or the input
    # tokens TypeSafe reports at its published rate.
    def cost_of(via, usage)
      return usage&.dig("cost") unless via.typesafe?

      tokens = usage&.dig("input_tokens")
      tokens.is_a?(Integer) ? tokens * TYPESAFE_USD_PER_INPUT_TOKEN : nil
    end

    def credits(via)
      return nil if via.typesafe?

      request = Net::HTTP::Get.new(CREDITS)
      request["Authorization"] = "Bearer #{via.key}"
      response = Net::HTTP.start(CREDITS.hostname, CREDITS.port, use_ssl: true) { |h| h.request(request) }
      JSON.parse(response.body)["data"]
    end
  end
end
