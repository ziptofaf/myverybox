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
  end
  
  describe "GET /show" do
    it 'shows a file if it belongs to user' do
      upload = create(:file_upload, user:)
      get "/file_uploads/#{upload.id}"
      expect(response).to have_http_status(302)
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
