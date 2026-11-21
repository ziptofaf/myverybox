class ApiKey < ApplicationRecord
  # value of the expiration <select> => [label, duration (nil = never expires)]
  EXPIRATION_OPTIONS = {
    '7' => ['7 days', 7.days],
    '30' => ['30 days', 30.days],
    '90' => ['90 days', 90.days],
    '365' => ['1 year', 1.year],
    'never' => ['Never', nil]
  }.freeze
  DEFAULT_EXPIRATION = '90'.freeze

  belongs_to :user

  # Only a SHA-256 digest of the key is stored. The plaintext key is available
  # through #token right after creation and never again.
  attr_reader :token

  validates :description, presence: true, length: { maximum: 255 }, on: :create
  validates :value_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(active: true) }
  scope :usable, -> { active.where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # Returns the usable (active, not expired) key matching a plaintext token.
  def self.authenticate(token)
    return nil if token.blank?

    usable.find_by(value_digest: digest(token))
  end

  # Expiration chosen from EXPIRATION_OPTIONS (e.g. "30" or "never").
  def expires_in=(choice)
    option = EXPIRATION_OPTIONS.fetch(choice.to_s) { EXPIRATION_OPTIONS.fetch(DEFAULT_EXPIRATION) }
    self.expires_at = option.last&.from_now
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  private

  def generate_token
    return if value_digest.present?

    @token = "mvb_#{SecureRandom.urlsafe_base64(32)}"
    self.value_digest = self.class.digest(@token)
  end
end
