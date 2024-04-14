class ApiKey < ApplicationRecord
  belongs_to :user
  before_create :generate_value
  scope :active, -> { where(active: true) }
  
  def generate_value
    self.value ||= SecureRandom.urlsafe_base64(32)
  end
end
