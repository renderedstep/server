FactoryBot.define do
  # A FLOOR ONE GAME HAS REACHED, raising nothing. The place is in the
  # playthrough's own story; `arrived_at` is the story's clock, never a roll.
  factory :playthrough_floor_reached, class: "Playthrough::FloorReached" do
    association :playthrough
    location { association :location, :stub, story: playthrough.story }
    arrived_at { playthrough.story_now }

    # A FLOOR THAT RAISED THE GAME'S PLAYER TO LEVEL 4.
    trait :raised do
      level { 4 }
    end
  end
end
