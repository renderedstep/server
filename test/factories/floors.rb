FactoryBot.define do
  # A floor of four rooms, with no way down and none of its own words: the
  # place is a stub carrying the footprint the loader would derive for it
  # (`Floor.footprint`), so it is a place nobody has walked into yet. Nothing
  # here rolls; ask for a way down or words by passing them.
  factory :floor do
    location { association :location, :stub, width: 12, depth: 12 }
    rooms { 4 }
  end
end
