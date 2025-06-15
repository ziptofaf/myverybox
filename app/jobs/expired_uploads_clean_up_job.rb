class ExpiredUploadsCleanUpJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    if force || Setting.find_by(name: 'remove_expired_files')&.formatted_value == true
      FileUpload.where('expires_after < ?', Time.now).each(&:destroy)
    end
  end
end
