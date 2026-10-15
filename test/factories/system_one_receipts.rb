FactoryBot.define do
  factory :system_one_receipt do
    association :player
    purpose { "classifier" }
    transport { "typesafe_direct" }
    cost_usd { SystemOneReceipt::COST_PER_REQUEST_USD }
    cost_source { SystemOneReceipt::ESTIMATED }
  end
end
