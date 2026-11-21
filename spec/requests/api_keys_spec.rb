require 'rails_helper'

RSpec.describe "ApiKeys", type: :request do
  let(:user) { create(:user) }
  before :each do
    sign_in user
  end

  describe "GET /index" do
    it "lists keys by description without revealing their values" do
      key = user.api_keys.create!(description: 'Laptop ShareX')

      get "/api_keys"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Laptop ShareX')
      expect(response.body).not_to include(key.token)
      expect(response.body).not_to include(key.value_digest)
    end
  end

  describe "POST /create" do
    it 'creates a key and shows its value once, uncached' do
      expect {
        post "/api_keys", params: { api_key: { description: 'ShareX', expires_in: '30' } }
      }.to change { ApiKey.count }.by(1)

      key = ApiKey.last
      token = response.body[/mvb_[A-Za-z0-9_-]+/]
      expect(response).to have_http_status(:success)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(ApiKey.authenticate(token)).to eq key
      expect(key.description).to eq 'ShareX'

      get "/api_keys"
      expect(response.body).not_to include(token)
    end

    it 'does not create a key without a description' do
      expect {
        post "/api_keys", params: { api_key: { description: '', expires_in: '30' } }
      }.not_to change { ApiKey.count }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Description can&#39;t be blank")
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
      api_key2 = create(:api_key, user: user2)

      expect { delete "/api_keys/#{api_key2.id}" }.to_not change { ApiKey.count }

      expect(response).to have_http_status(302)
    end
  end
end
