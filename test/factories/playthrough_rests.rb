FactoryBot.define do
  # A REST ONE GAME TOOK, that mended eight. The place is in the playthrough's
  # own story; `story_timestamp` is the story's clock, never a roll.
  factory :playthrough_rest, class: "Playthrough::Rest" do
    association :playthrough
    location { association :location, :sanctuary, story: playthrough.story }
    recovered { 8 }
    hp_after { 14 }
    story_timestamp { playthrough.story_now }
  end
end
