class FileUpload < ApplicationRecord
  belongs_to :user
  has_one_attached :upload
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
    DescriptionFillingJob.set(wait: 1.second).perform_later(id)
    FileUploadCaptionJob.set(wait: 10.seconds).perform_later(id)
  end
end
