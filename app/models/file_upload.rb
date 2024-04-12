class FileUpload < ApplicationRecord
  belongs_to :user
  has_one_attached :upload
  
  def generate_url
    self.url ||= SecureRandom.urlsafe_base64(32)
  end
end
