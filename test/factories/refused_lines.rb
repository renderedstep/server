FactoryBot.define do
  # One free-typed line the local reader's reading refused, as the engine keeps
  # it: here an unsure act, asked about. See RefusedLine.
  factory :refused_line do
    typed { "approach Tamsin" }
    state do
      { "command" => "approach Tamsin", "location" => "The Counting House",
        "people" => [ "Tamsin Gale", "Rowe Harker" ] }
    end
    answers do
      { "intent" => { "choice" => "talk", "probabilities" => { "talk" => 0.55, "attack" => 0.45 } },
        "target_talk" => { "choice" => "person_1", "probabilities" => { "person_1" => 1.0 } } }
    end
    reading do
      { "action" => "talk", "target" => "Tamsin Gale", "also_named" => nil, "resolved_by" => "typed_model_unsure" }
    end
    act_confidence { 0.55 }
    thing_confidence { 1.0 }
    refusal do
      { "kind" => "unsure", "typed" => "approach Tamsin",
        "fact" => "The game is not sure what you meant by that, so nothing has happened.",
        "offer" => "Its best guess was `/talk Tamsin Gale`. Type that to do it, or say what you meant another way." }
    end
    place { "The Counting House" }
    weights { "pointer-032123780e5fb34c" }

    # The reader was never asked, because it was down.
    trait :unread do
      answers { nil }
      act_confidence { nil }
      thing_confidence { nil }
      reading { { "action" => "other", "target" => nil, "also_named" => nil, "resolved_by" => "typed_model_down" } }
      refusal { { "kind" => "unreadable", "typed" => "approach Tamsin", "fact" => "The game cannot read free-typed lines right now." } }
    end
  end
end
