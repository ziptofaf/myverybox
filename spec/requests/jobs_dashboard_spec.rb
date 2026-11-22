require 'rails_helper'

RSpec.describe "Background jobs dashboard (Mission Control)", type: :request do
  it 'sends signed-out visitors to sign in, including deep links' do
    ['/jobs', '/jobs/applications/myverybox/queues', '/jobs/applications/myverybox/failed/jobs'].each do |path|
      get path

      expect(response).to redirect_to('/users/sign_in'), path
    end
  end

  it 'does not accept HTTP basic auth instead of signing in' do
    get '/jobs', headers: { 'Authorization' => ActionController::HttpAuthentication::Basic.encode_credentials('admin', 'admin') }

    expect(response).to redirect_to('/users/sign_in')
  end

  context 'when signed in' do
    before { sign_in create(:user) }

    it 'shows the dashboard' do
      get '/jobs'
      follow_redirect! while response.redirect?

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Queues')
    end
  end
end
