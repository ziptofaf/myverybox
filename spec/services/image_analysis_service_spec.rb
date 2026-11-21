require 'rails_helper'

RSpec.describe ImageAnalysisService do
  let(:file_upload) { create(:file_upload) }
  let(:ok_response) { instance_double(HTTParty::Response, code: 200, body: 'A tiny letter A.') }

  before do
    # settings are unique by name (and may already exist when the db is seeded)
    Setting.find_or_initialize_by(name: 'image_description_analysis')
           .update!(value_type: 'bool', value: enabled)
  end

  context 'when image description analysis is enabled' do
    let(:enabled) { '1' }

    it 'posts the image bytes to the description service and stores the result' do
      expect(HTTParty).to receive(:post).with(
        'http://clippy.test:3001/',
        body: file_upload.upload.blob.download,
        headers: { 'Content-Type' => 'image/png' },
        timeout: 30
      ).and_return(ok_response)

      described_class.new(file_upload).call

      expect(file_upload.reload.description).to eq 'A tiny letter A.'
    end

    it 'does not send files that are not images' do
      file_upload.upload.blob.update!(content_type: 'application/pdf')
      expect(HTTParty).not_to receive(:post)

      described_class.new(file_upload).call
    end

    it 'leaves the description empty when the service is unreachable' do
      allow(HTTParty).to receive(:post).and_raise(SocketError)

      expect { described_class.new(file_upload).call }.not_to raise_error
      expect(file_upload.reload.description).to be_nil
    end
  end

  context 'when image description analysis is disabled' do
    let(:enabled) { '0' }

    it 'does not call the description service' do
      expect(HTTParty).not_to receive(:post)

      described_class.new(file_upload).call
    end
  end
end
