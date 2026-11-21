require 'rails_helper'

RSpec.describe "FileUploads", type: :request do
  let(:user) { create(:user) }
  before :each do
    sign_in user
  end
  
  describe "GET /index" do
    it "returns http success" do
      get "/file_uploads"
      expect(response).to have_http_status(:success)
    end

    it "renders a lazily loaded larger preview for image uploads" do
      create(:file_upload, user:)
      get "/file_uploads"

      preview = Nokogiri::HTML(response.body).at_css('.hover-preview img.hover-preview-image')
      expect(preview).to be_present
      expect(preview['loading']).to eq 'lazy'
      expect(preview['src']).to include('/rails/active_storage/representations/')

      get preview['src']
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq 'image/png'
    end
  end
  
  describe "GET /show" do
    it 'shows a file if it belongs to user' do
      upload = create(:file_upload, user:)
      get "/file_uploads/#{upload.id}"
      expect(response).to have_http_status(:success)
    end

    it 'does not show a file belonging to a different user' do
      user2 = create(:user)
      upload = create(:file_upload, user: user2)
      get "/file_uploads/#{upload.id}"
      expect(response).to have_http_status(404)
      expect(response.body.include?('File you have been looking for no longer exists')).to eq true
    end
  end
end
