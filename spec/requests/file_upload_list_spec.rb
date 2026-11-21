require 'rails_helper'

RSpec.describe "Uploads list: pagination and sorting", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  def upload(name, size:, created_at:)
    create(:file_upload, user:).tap do |f|
      f.upload.blob.update_columns(filename: name, byte_size: size)
      f.update_columns(created_at: created_at)
    end
  end

  def page_doc = Nokogiri::HTML(response.body)
  def listed = page_doc.css('tbody tr').map { |row| row.at_css('td').text.strip }
  def page_links = page_doc.css('.pagination.menu .item').map(&:text)

  describe 'pagination' do
    before do
      25.times { |i| upload("file#{i}.png", size: 100 + i, created_at: (25 - i).hours.ago) }
    end

    it 'shows totals and numbered pages' do
      get '/file_uploads'

      expect(page_doc.at_css('.list-summary').text).to eq 'Showing 1–10 of 25 files'
      expect(page_links).to eq ['‹ Previous', '1', '2', '3', 'Next ›']
      expect(page_doc.at_css('.pagination .active.item').text).to eq '1'
      expect(listed.first).to eq 'file24.png' # newest first by default
    end

    it 'shows the last, partial page and clamps out-of-range pages to it' do
      get '/file_uploads', params: { page: 3 }
      expect(listed.size).to eq 5
      expect(page_doc.at_css('.list-summary').text).to eq 'Showing 21–25 of 25 files'

      get '/file_uploads', params: { page: 999 }
      expect(page_doc.at_css('.pagination .active.item').text).to eq '3'
    end
  end

  describe 'sorting' do
    before do
      upload('small-old.png', size: 10, created_at: 3.days.ago)
      upload('big-new.png', size: 9_000, created_at: 1.day.ago)
      upload('medium-mid.png', size: 500, created_at: 2.days.ago)
    end

    it 'sorts by file size in both directions' do
      get '/file_uploads', params: { sort: 'size', direction: 'desc' }
      expect(listed).to eq %w[big-new.png medium-mid.png small-old.png]

      get '/file_uploads', params: { sort: 'size', direction: 'asc' }
      expect(listed).to eq %w[small-old.png medium-mid.png big-new.png]
    end

    it 'sorts by upload date, oldest first on request' do
      get '/file_uploads', params: { sort: 'uploaded', direction: 'asc' }
      expect(listed).to eq %w[small-old.png medium-mid.png big-new.png]
    end

    it 'ignores unknown sort columns' do
      get '/file_uploads', params: { sort: 'user_id; drop table users', direction: 'sideways' }
      expect(response).to have_http_status(:success)
      expect(listed).to eq %w[big-new.png medium-mid.png small-old.png]
    end

    it 'links the active column to the opposite direction' do
      get '/file_uploads', params: { sort: 'size', direction: 'desc' }
      link = page_doc.css('th a').find { |a| a.text.start_with?('File size') }
      expect(link.text).to eq 'File size ▼'
      expect(link['href']).to include('direction=asc')
    end
  end

  describe 'in search results' do
    it 'keeps the filters and sort order in page links' do
      12.times { |i| upload("report#{i}.png", size: i, created_at: i.hours.ago) }

      get '/file_uploads/search_results', params: { search: { filename: 'report' }, sort: 'size', direction: 'asc' }

      expect(page_doc.at_css('.list-summary').text).to eq 'Showing 1–10 of 12 files'
      next_href = page_doc.at_css('.pagination a[rel=next]')['href']
      expect(next_href).to include('search%5Bfilename%5D=report', 'sort=size', 'direction=asc', 'page=2')
    end

    it 'orders "What\'s in the image?" results by relevance and counts only embedded images' do
      a = upload('a.png', size: 1, created_at: 1.day.ago).tap { |f| f.update_columns(embedding: Array.new(768) { |i| i.zero? ? 1.0 : 0.0 }) }
      upload('b.png', size: 2, created_at: 2.days.ago) # no embedding yet
      client = instance_double(ImageEmbeddingClient)
      allow(ImageEmbeddingClient).to receive(:new).and_return(client)
      allow(client).to receive(:for_text).and_return(ImageEmbeddingClient::Result.new(model: 'test', embedding: a.embedding))

      get '/file_uploads/search_results', params: { search: { content: 'anything' } }

      expect(listed).to eq %w[a.png]
      expect(page_doc.at_css('.list-summary').text).to eq 'Showing 1–1 of 1 files'
      expect(response.body).to include('Sorted by best match')
      expect(page_doc.css('th a')).to be_empty # no sort links while ranked by relevance
    end
  end
end
