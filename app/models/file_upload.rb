class FileUpload < ApplicationRecord
  belongs_to :user
  has_one_attached :upload
  before_create :generate_url
  
  def generate_url
    self.url ||= SecureRandom.urlsafe_base64(32)
  end
  
  def expires_in_seconds=(value)
    self.expires_after = value.to_i.seconds.from_now
  end
  
  def expired?
    expires_after.present? && expires_after < Time.now
  end
  
  def active?
    !expired?
  end
end
