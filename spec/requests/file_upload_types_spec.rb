require 'rails_helper'

RSpec.describe "Listing and serving different file types", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "GET /file_uploads" do
    it "renders when an SVG has been uploaded, showing the SVG itself as thumbnail" do
      svg = create(:file_upload, user:, fixture: 'upload.svg', content_type: 'image/svg+xml')

      get "/file_uploads"

      expect(response).to have_http_status(:success)
      img = Nokogiri::HTML(response.body).at_css('img.svg-miniature')
      expect(img['src']).to eq "/show/#{svg.url}"
    end

    it "still renders the list when generating a thumbnail fails" do
      create(:file_upload, user:)
      allow_any_instance_of(ActiveStorage::VariantWithRecord).to receive(:processed)
        .and_raise(ActiveStorage::Error, 'boom')

      get "/file_uploads"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('upload.png')
    end
  end

  describe "serving files" do
    it "sandboxes active content such as SVG so embedded scripts cannot run" do
      svg = create(:file_upload, user:, fixture: 'upload.svg', content_type: 'image/svg+xml')

      get "/show/#{svg.url}"

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq 'image/svg+xml'
      expect(response.headers['Content-Security-Policy']).to start_with('sandbox')

      get "/file_uploads/#{svg.id}"
      expect(response.headers['Content-Security-Policy']).to start_with('sandbox')
    end

    it "serves regular images without the sandbox (keeps PDFs/images/videos viewable)" do
      png = create(:file_upload, user:)

      get "/show/#{png.url}"

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Security-Policy'].to_s).not_to include('sandbox')
    end
  end
end
