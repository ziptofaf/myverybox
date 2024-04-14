FactoryBot.define do
  factory :file_upload do
    user
    expires_after { nil }

    after(:build) do |file_upload|
      file_upload.upload.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'upload.png')),
        filename: 'upload.png',
        content_type: 'image/png'
      )
    end
  end
end
