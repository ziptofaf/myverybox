require 'rails_helper'

RSpec.describe FileUpload, type: :model do
  describe 'creation' do
    let(:user) { create(:user) }

    it 'adds url automatically' do
      upload = create(:file_upload, user:)
      expect(upload.url).to_not be_nil
    end
  end

  describe 'expiration' do
    let(:user) { create(:user) }

    it 'is always active if flag is not set' do
      upload = create(:file_upload, user:)
      expect(upload.active?).to eq true
    end
    
    it 'is not active if date is in the past' do
      upload = create(:file_upload, user:)
      upload.update(expires_after: 1.year.ago)
      expect(upload.active?).to eq false
    end
    
    it 'allows you to set expiration via expires_in_seconds' do
      upload = create(:file_upload, expires_in_seconds: 86400, user:)
      expect(upload.expires_after).to be_within(20.seconds).of(1.day.from_now)
    end
  end
end
