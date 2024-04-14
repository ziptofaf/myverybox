FactoryBot.define do
  factory :api_key do
    user
    value { "MyString" }
    active { true }
  end
end
