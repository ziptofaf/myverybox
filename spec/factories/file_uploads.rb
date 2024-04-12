FactoryBot.define do
  factory :file_upload do
    user { nil }
    expires_after { "2024-04-12 23:16:30" }
    url { "MyString" }
    uploaded_file { nil }
  end
end
