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

  def listed_ids
    Nokogiri::HTML(response.body).css('tbody tr').map { |row| row.at_css('td').text.strip }
  end

  describe "searching by what's in the image" do
    let!(:dog) { create(:file_upload, user:).tap { |f| f.update_columns(embedding: axis(0), embedding_model: 'test') } }
    let!(:cat) { create(:file_upload, user:).tap { |f| f.update_columns(embedding: axis(1), embedding_model: 'test') } }
    let!(:not_embedded) { create(:file_upload, user:) }
    let(:client) { instance_double(ImageEmbeddingClient) }

    before do
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
