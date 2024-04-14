require 'rails_helper'

RSpec.describe "ApiKeys", type: :request do
  let(:user) { create(:user) }
  before :each do
    sign_in user
  end

  describe "GET /index" do
    it "returns http success" do
      get "/api_keys"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it 'creates an API key' do
      expect { post "/api_keys" }.to change { ApiKey.count }.by(1)
      
      expect(response).to have_http_status(302)
    end
  end
  
  describe "DELETE /destroy" do
    let!(:api_key) { create(:api_key, user:) }
    
    it 'destroys' do
      expect { delete "/api_keys/#{api_key.id}" }.to change { ApiKey.count }.by(-1)

      expect(response).to have_http_status(302)
    end

    it 'does not destroy if it belongs to someone else' do
      user2 = create(:user)
      api_key2 =  create(:api_key, user: user2)

      expect { delete "/api_keys/#{api_key2.id}" }.to_not change { ApiKey.count }

      expect(response).to have_http_status(302)
    end
  end
end
