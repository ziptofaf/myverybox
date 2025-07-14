class FileUploadCaptionJob < ApplicationJob
  def perform(file_upload_id)
    file_upload = FileUpload.find_by(id: file_upload_id)
    return unless file_upload
    return unless file_upload.upload.blob.content_type.include?('image')
    
    file_upload_caption = FileUploadOcr.new(file_upload).text
    file_upload.update(caption: file_upload_caption)
  end
end