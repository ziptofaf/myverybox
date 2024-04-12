require 'rails_helper'

RSpec.describe "FileUploads", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/file_uploads/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/file_uploads/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/file_uploads/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show_via_url" do
    it "returns http success" do
      get "/file_uploads/show_via_url"
      expect(response).to have_http_status(:success)
    end
  end

end
