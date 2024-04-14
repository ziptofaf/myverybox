FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { '1234567#a' }
    password_confirmation { '1234567#a' }
  end
end