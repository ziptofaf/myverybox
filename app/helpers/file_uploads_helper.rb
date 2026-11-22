module FileUploadsHelper
  # e.g. "never expire" or "expire 1 day after upload" (System settings)
  def default_expiry_description
    seconds = Setting.find_by(name: 'expires_in_seconds')&.formatted_value.to_i
    return 'never expire' unless seconds.positive?

    "expire #{distance_of_time_in_words(seconds)} after upload"
  end
end
