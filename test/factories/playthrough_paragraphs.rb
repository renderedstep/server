FactoryBot.define do
  # What the player wrote for one turn of a game they narrate. See
  # Playthrough::Paragraph.
  #
  # NOT CHECKED BY DEFAULT: `audit` is left nil, as a row is between the engine
  # writing it and the session checking it. `:checked` is a clean check and
  # `:flagged` one the check found something in; neither is a finding of
  # `Story::Audit`'s, only rows that look like one.
  factory :playthrough_paragraph, class: "Playthrough::Paragraph" do
    playthrough { association :playthrough, mode: "player_narrates" }
    scene { association :scene, story: playthrough.story }
    text { "You lift the ward stamp off the counter and weigh it in your hand." }

    trait :checked do
      audit { { "flags" => [] } }
    end

    trait :flagged do
      audit do
        { "flags" => [ { "code" => "truncated_prose", "headline" => "the narration the player read stops mid-sentence",
                         "evidence" => "…and then the" } ] }
      end
    end
  end
end
