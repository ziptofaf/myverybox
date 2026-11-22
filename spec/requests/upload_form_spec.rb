require 'rails_helper'

RSpec.describe "Upload form", type: :request do
  let(:user) { create(:user) }
  let(:file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/upload.png'), 'image/png') }
  before { sign_in user }

  def upload(expires_after: nil, time_zone: nil, with_file: true)
    params = { file_upload: { expires_after: expires_after } }
    params[:file_upload][:upload] = file if with_file
    params[:time_zone] = time_zone if time_zone
    post '/file_uploads', params: params
  end

  def default_expiry(seconds)
    Setting.find_or_initialize_by(name: 'expires_in_seconds').update!(value_type: 'number', value: seconds.to_s)
  end

  it 'shows an optional expiry field' do
    get '/file_uploads/new'

    field = Nokogiri::HTML(response.body).at_css('input[type="datetime-local"][name="file_upload[expires_after]"]')
    expect(field).to be_present
    expect(field['required']).to be_nil
    expect(response.body).to include('never expire') # default without a setting
  end

  it 'interprets the entered time in the browser time zone' do
    travel_to Time.utc(2026, 11, 22, 10) do
      upload(expires_after: '2026-11-22T18:30', time_zone: 'Europe/Warsaw') # UTC+1 in November
    end

    expect(response).to redirect_to('/file_uploads')
    expect(user.file_uploads.last.expires_after).to eq Time.utc(2026, 11, 22, 17, 30)
  end

  it 'falls back to UTC without a (valid) browser time zone' do
    travel_to Time.utc(2026, 11, 22, 10) do
      upload(expires_after: '2026-11-22T18:30', time_zone: 'Not/AZone')
    end

    expect(user.file_uploads.last.expires_after).to eq Time.utc(2026, 11, 22, 18, 30)
  end

  it 'uses the default expiry from System settings when left empty' do
    default_expiry(3600)

    freeze_time do
      upload(expires_after: '')
      expect(user.file_uploads.last.expires_after).to eq 1.hour.from_now
    end
  end

  it 'never expires when left empty and there is no default' do
    default_expiry(0)

    upload(expires_after: '')

    expect(user.file_uploads.last.expires_after).to be_nil
  end

  it 'rejects an expiry in the past' do
    expect { upload(expires_after: '2020-01-01T10:00', time_zone: 'Europe/Warsaw') }.not_to(change { FileUpload.count })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Expires after must be in the future')
  end

  it 'rejects a malformed expiry' do
    expect { upload(expires_after: 'next tuesday-ish') }.not_to(change { FileUpload.count })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('is not a valid date and time')
  end

  it 'requires a file' do
    expect { upload(with_file: false) }.not_to(change { FileUpload.count })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Upload must be selected')
  end
end
