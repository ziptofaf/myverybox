require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/dashboard/index"
      expect(response).to have_http_status(:success)
    end
  end
  
  describe "GET /not_found" do
    it 'returns http success' do
      get '/dashboard/not_found'
      expect(response).to have_http_status(:success)
    end
  end

end
