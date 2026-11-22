# Deletes uploads past their expiration date. Scheduled daily by Solid Queue
# (config/recurring.yml); only acts when enabled in System settings, unless
# forced (the "Remove expired files" button).
class ExpiredUploadsCleanUpJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    return unless force || Setting.find_by(name: 'remove_expired_files')&.formatted_value == true

    removed = 0
    FileUpload.where('expires_after < ?', Time.current).find_each do |file_upload|
      file_upload.destroy
      removed += 1
    end
    Rails.logger.info("ExpiredUploadsCleanUpJob: removed #{removed} expired uploads")
    removed
  end
end
