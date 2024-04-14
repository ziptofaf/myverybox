require 'rails_helper'

RSpec.describe "FileUploads", type: :request do
  before :each do
    sign_in create(:user)
  end
  
  describe "GET /index" do
    it "returns http success" do
      get "/file_uploads"
      expect(response).to have_http_status(:success)
    end
  end
end
