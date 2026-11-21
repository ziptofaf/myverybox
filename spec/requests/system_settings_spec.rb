require 'rails_helper'

RSpec.describe "System settings", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  it 'shows database size, upload totals and free disk space' do
    create(:file_upload, user:)

    get '/system_settings/index'

    expect(response).to have_http_status(:success)
    page = Nokogiri::HTML(response.body)
    rows = page.css('table.definition tr').to_h { |tr| [tr.css('td')[0].text.strip, tr.css('td')[1].text.squish] }
    expect(rows['Database']).to match(/\d+(\.\d+)? (KB|MB|GB)/)
    expect(rows['Uploaded files']).to include('in 1 files')
    expect(rows['Disk holding uploaded files']).to match(/free of .* used\)/)
  end

  it 'still renders when the disk figures are unavailable' do
    allow_any_instance_of(StorageStats).to receive(:disk).and_return(nil)

    get '/system_settings/index'

    expect(response).to have_http_status(:success)
    expect(response.body).to include('not available')
  end
end
