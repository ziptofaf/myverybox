# Creates the converted copy of an upload (see UploadConversion), then runs
# the usual analysis on that copy.
class UploadConversionJob < ApplicationJob
  queue_as :default

  def perform(file_upload_id)
    file_upload = FileUpload.find_by(id: file_upload_id)
    return unless file_upload

    file_upload.ensure_converted!
    # also when the conversion failed: analysis then just works on the original
    file_upload.schedule_analysis
  end
end
