require 'rails_helper'

RSpec.describe ImageEmbeddingClient do
  subject(:client) { described_class.new(base_url: 'http://clippy.test:3001') }

  let(:vector) { Array.new(768) { 0.01 } }
  let(:ok) { instance_double(HTTParty::Response, code: 200, body: { model: 'siglip2', dimensions: 768, embedding: vector }.to_json) }

  describe '#for_blob' do
    it 'posts image bytes and returns the embedding' do
      upload = create(:file_upload)
      expect(HTTParty).to receive(:post).with(
        'http://clippy.test:3001/embed/image',
        body: upload.upload.blob.download, headers: { 'Content-Type' => 'image/png' }, timeout: 60
      ).and_return(ok)

      result = client.for_blob(upload.upload.blob)

      expect(result.model).to eq 'siglip2'
      expect(result.embedding.size).to eq 768
    end

    it 'skips files that are not raster images' do
      svg = create(:file_upload, fixture: 'upload.svg', content_type: 'image/svg+xml')
      expect(HTTParty).not_to receive(:post)

      expect(client.for_blob(svg.upload.blob)).to be_nil
    end
  end

  describe '#for_text' do
    it 'returns nil when the service is unreachable' do
      allow(HTTParty).to receive(:post).and_raise(Errno::ECONNREFUSED)

      expect(client.for_text('a dog')).to be_nil
    end

    it 'returns nil for an error response' do
      allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, code: 500, body: 'Error'))

      expect(client.for_text('a dog')).to be_nil
    end
  end
end
