FactoryBot.define do
  factory :file_upload do
    user
    expires_after { nil }

    transient do
      fixture { 'upload.png' }
      content_type { 'image/png' }
    end

    after(:build) do |file_upload, evaluator|
      file_upload.upload.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', evaluator.fixture)),
        filename: evaluator.fixture,
        content_type: evaluator.content_type
      )
    end
  end
end
