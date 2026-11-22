require 'rails_helper'

RSpec.describe "Uploading via the API", type: :request do
  let(:user) { create(:user) }
  let(:file) { Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'upload.png'), 'image/png') }

  # ShareX sends an "api_key" header; Rack exposes it as HTTP_API_KEY. (The
  # integration test helper only maps dash-separated names, so set it directly.)
  def upload(token)
    post "/file_uploads/upload_via_api", params: { upload: file }, headers: { 'HTTP_API_KEY' => token }
  end

  it 'accepts a valid key and records when it was used' do
    key = user.api_keys.create!(description: 'ShareX')

    expect { upload(key.token) }.to change { user.file_uploads.count }.by(1)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq 'ok'
    expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
  end

  it 'rejects an expired key' do
    key = user.api_keys.create!(description: 'ShareX', expires_in: '7')

    travel 8.days do
      expect { upload(key.token) }.not_to change { FileUpload.count }
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'rejects an expiry in the past with the reason' do
    key = user.api_keys.create!(description: 'ShareX')

    post "/file_uploads/upload_via_api", params: { upload: file, expires_after: 1.day.ago.iso8601 },
                                         headers: { 'HTTP_API_KEY' => key.token }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['errors']).to include('Expires after must be in the future')
  end

  it 'rejects an unknown key' do
    expect { upload('mvb_not-a-real-key') }.not_to change { FileUpload.count }

    expect(response).to have_http_status(:forbidden)
  end
end
