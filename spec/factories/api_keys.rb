FactoryBot.define do
  factory :api_key do
    user { nil }
    value { "MyString" }
    active { false }
  end
end
