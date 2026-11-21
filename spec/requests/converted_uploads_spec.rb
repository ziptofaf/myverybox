require 'rails_helper'

RSpec.describe "Serving converted uploads", type: :request do
  let(:user) { create(:user) }
  let(:heic) { create(:file_upload, user:, fixture: 'upload.heic', content_type: 'image/heic') }

  it 'serves the PNG copy on the share link, converting on demand' do
    get "/show/#{heic.url}"

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq 'image/png'
    expect(response.headers['Content-Disposition']).to start_with('inline')
  end

  it 'offers the untouched original as a download' do
    get "/show/#{heic.url}/original"

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq 'image/heic'
    expect(response.headers['Content-Disposition']).to start_with('attachment')
    expect(response.body.b).to eq File.binread(Rails.root.join('spec/fixtures/upload.heic'))
  end

  it 'returns 404 for the original of an unknown or expired upload' do
    get "/show/does-not-exist/original"
    expect(response).to have_http_status(:not_found)

    heic.update_columns(expires_after: 1.day.ago)
    get "/show/#{heic.url}/original"
    expect(response).to have_http_status(:not_found)
  end

  it 'marks converted uploads in the list and links the original' do
    heic.ensure_converted!
    create(:file_upload, user:) # a PNG: no label, no button
    sign_in user

    get '/file_uploads'

    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.ui.label').map(&:text).map(&:squish)).to eq ['HEIC → PNG']
    originals = doc.css('a').select { |a| a.text == 'Original' }
    expect(originals.map { |a| a['href'] }).to eq ["/show/#{heic.url}/original"]
  end

  it 'returns the converted URL plus the original from the API' do
    key = user.api_keys.create!(description: 'ShareX')
    file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/upload.heic'), 'image/heic')

    post '/file_uploads/upload_via_api', params: { upload: file }, headers: { 'HTTP_API_KEY' => key.token }

    body = response.parsed_body
    expect(body['url']).to match(%r{/show/[\w-]+\z})
    expect(body['original_url']).to eq "#{body['url']}/original"
  end
end
