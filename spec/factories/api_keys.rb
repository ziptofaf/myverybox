FactoryBot.define do
  factory :api_key do
    user
    description { "ShareX" }
    active { true }
    expires_at { nil }
  end
end
