class FileUpload < ApplicationRecord
  belongs_to :user
  has_one_attached :upload
  # browser-friendly copy for formats browsers can't show, see UploadConversion
  has_one_attached :converted
  has_neighbors :embedding
  before_create :generate_url
  after_create_commit :fill_metadata

  def generate_url
    self.url ||= SecureRandom.urlsafe_base64(32)
  end

  def expires_in_seconds=(value)
    return if value == 0
    self.expires_after = value.to_i.seconds.from_now
  end

  def expired?
    expires_after.present? && expires_after < Time.now
  end

  def active?
    !expired?
  end

  def megabyte_size
    (upload.blob.byte_size / 1024.0 / 1024.0).round(2)
  end

  def fill_metadata
    if conversion
      # the job schedules the analysis once the converted copy exists
      UploadConversionJob.set(wait: 1.second).perform_later(id)
    else
      schedule_analysis
    end
  end

  def schedule_analysis
    DescriptionFillingJob.set(wait: 1.second).perform_later(id)
    FileUploadCaptionJob.set(wait: 10.seconds).perform_later(id)
    FileUploadEmbeddingJob.set(wait: 5.seconds).perform_later(id)
  end

  # The UploadConversion rule for this upload's format (nil = served as is).
  def conversion
    UploadConversion.for(upload.blob&.content_type)
  end

  # The file to show and analyse: the converted copy when there is one.
  def display_blob
    converted.attached? ? converted.blob : upload.blob
  end

  # The file to serve by default (share links, API URLs). Converts on demand
  # when the rule allows it and the background job hasn't finished yet, e.g.
  # ShareX opening the link right after uploading.
  def display_attachment!
    ensure_converted! if conversion&.on_demand?
    converted.attached? ? converted.attachment : upload.attachment
  end

  # Creates the converted copy if this upload needs one. Safe to call
  # concurrently (row lock); returns false if the conversion failed, in which
  # case the original keeps being used.
  def ensure_converted!
    rule = conversion
    return true if rule.nil? || converted.attached?

    output = nil
    with_lock do
      reload
      next if converted.attached?

      output = convert_with(rule)
      converted.attach(io: output, filename: "#{upload.blob.filename.base}.#{rule.extension}", content_type: rule.to)
    end
    true
  rescue UploadConversion::Error, ActiveStorage::FileNotFoundError => e
    Rails.logger.warn("#{rule&.name} conversion of FileUpload##{id} failed: #{e.message}")
    false
  ensure
    # only after with_lock returned: Active Storage uploads the file when that transaction commits
    output&.close!
  end

  # Fetches and stores the image embedding (semantic search). Returns true when
  # an embedding was stored; non-images and clippy outages just return false.
  def store_embedding!(client: ImageEmbeddingClient.new)
    result = client.for_blob(display_blob)
    return false unless result

    update_columns(embedding: result.embedding, embedding_model: result.model)
    true
  end

  private

  # Runs the rule's converter on a local copy of the original; returns a Tempfile.
  def convert_with(rule)
    upload.blob.open { |original| rule.converter.call(original.path) }
  end
end
