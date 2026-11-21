require 'rails_helper'

RSpec.describe "Searching uploads", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  # unit vector along one axis of the 768-dimensional embedding space
  def axis(index)
    Array.new(768, 0.0).tap { |v| v[index] = 1.0 }
  end

  def search(params)
    get "/file_uploads/search_results", params: { search: params }
  end

  def image_analysis(enabled)
    Setting.find_or_initialize_by(name: Setting::IMAGE_ANALYSIS).update!(value_type: 'bool', value: enabled ? '1' : '0')
  end

  describe 'the search form' do
    it "offers \"What's in the image?\" when image analysis is enabled" do
      image_analysis(true)
      get '/file_uploads/search'
      expect(response.body).to include("What&#39;s in the image?")
    end

    it 'hides it when image analysis is disabled' do
      image_analysis(false)
      get '/file_uploads/search'
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("What&#39;s in the image?")
      expect(response.body).to include('Name of the file')
    end
  end

  def listed_ids
    Nokogiri::HTML(response.body).css('tbody tr').map { |row| row.at_css('td').text.strip }
  end

  describe "searching by what's in the image" do
    let!(:dog) { create(:file_upload, user:).tap { |f| f.update_columns(embedding: axis(0), embedding_model: 'test') } }
    let!(:cat) { create(:file_upload, user:).tap { |f| f.update_columns(embedding: axis(1), embedding_model: 'test') } }
    let!(:not_embedded) { create(:file_upload, user:) }
    let(:client) { instance_double(ImageEmbeddingClient) }

    before do
      image_analysis(true)
      dog.upload.blob.update!(filename: 'dog.png')
      cat.upload.blob.update!(filename: 'cat.png')
      not_embedded.upload.blob.update!(filename: 'other.png')
      allow(ImageEmbeddingClient).to receive(:new).and_return(client)
    end

    it 'orders results by similarity to the query' do
      query = [0.2, 0.9] + Array.new(766, 0.0) # much closer to "cat"
      allow(client).to receive(:for_text).with('a cat')
        .and_return(ImageEmbeddingClient::Result.new(model: 'test', embedding: query))

      search(content: 'a cat')

      expect(response).to have_http_status(:success)
      expect(listed_ids).to eq %w[cat.png dog.png]
    end

    it 'does not leak other users uploads' do
      other = create(:file_upload).tap { |f| f.update_columns(embedding: axis(1)) }
      other.upload.blob.update!(filename: 'someone-elses.png')
      allow(client).to receive(:for_text).and_return(ImageEmbeddingClient::Result.new(model: 'test', embedding: axis(1)))

      search(content: 'a cat')

      expect(listed_ids).not_to include('someone-elses.png')
    end

    it 'ignores the image query while image analysis is disabled (e.g. an old bookmarked link)' do
      image_analysis(false)
      expect(client).not_to receive(:for_text)

      search(content: 'a cat')

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Sorted by best match')
      expect(listed_ids).to eq %w[other.png cat.png dog.png] # regular newest-first list
    end

    it 'shows an error instead of crashing when the analysis service is down' do
      allow(client).to receive(:for_text).and_return(nil)

      search(content: 'a cat')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Searching by image content is unavailable')
      expect(listed_ids).to be_empty
    end
  end

  describe 'text filters' do
    let!(:upload) do
      create(:file_upload, user:).tap do |f|
        f.update_columns(description: 'A Dog on a beach', caption: "Invoice 4711\nTotal due: 128.50 EUR")
        f.upload.blob.update!(filename: 'Holiday_Photo.png')
      end
    end

    it 'matches descriptions case-insensitively' do
      search(description: 'dog')
      expect(listed_ids).to eq %w[Holiday_Photo.png]
    end

    it 'matches text found in the image (OCR)' do
      search(description: 'invoice 4711')
      expect(listed_ids).to eq %w[Holiday_Photo.png]
    end

    it 'matches filenames case-insensitively and treats % literally' do
      search(filename: 'holiday')
      expect(listed_ids).to eq %w[Holiday_Photo.png]

      search(filename: '%')
      expect(listed_ids).to be_empty
    end

    it 'filters by upload date without errors' do
      search(created_at_from: 1.day.ago.to_date.to_s, created_at_to: 1.day.from_now.to_date.to_s)
      expect(response).to have_http_status(:success)
      expect(listed_ids).to eq %w[Holiday_Photo.png]
    end
  end
end
