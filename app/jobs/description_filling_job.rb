class DescriptionFillingJob < ApplicationJob
  queue_as :default

  def perform(file_upload_id)
    file_upload = FileUpload.find_by(id: file_upload_id)
    return unless file_upload
    
    ImageAnalysisService.new(file_upload).call
  end
end