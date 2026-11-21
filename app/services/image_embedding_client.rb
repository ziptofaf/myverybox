# Talks to the clippy service to turn images and search queries into SigLIP 2
# embeddings (same vector space, so a text query can be compared to images).
class ImageEmbeddingClient
  Result = Data.define(:model, :embedding)

  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
                    Errno::EHOSTUNREACH, SocketError].freeze

  def initialize(base_url: Settings.image_analysis_hostname)
    @base_url = base_url
  end

  # Returns a Result, or nil if the blob can't be embedded / clippy is unavailable.
  def for_blob(blob)
    return nil unless embeddable?(blob)

    post('/embed/image', blob.download, blob.content_type, timeout: 60)
  end

  def for_text(text)
    return nil if text.blank?

    post('/embed/text', text.to_s, 'text/plain; charset=utf-8', timeout: 10)
  end

  def embeddable?(blob)
    type = blob.content_type.to_s
    type.start_with?('image/') && type != 'image/svg+xml'
  end

  private

  def post(path, body, content_type, timeout:)
    res = HTTParty.post(@base_url.to_s + path, body: body, headers: { 'Content-Type' => content_type }, timeout: timeout)
    return nil unless res.code == 200

    data = JSON.parse(res.body)
    Result.new(model: data.fetch('model'), embedding: data.fetch('embedding'))
  rescue *NETWORK_ERRORS, JSON::ParserError, KeyError => e
    Rails.logger.warn("ImageEmbeddingClient #{path} failed: #{e.class}: #{e.message}")
    nil
  end
end
