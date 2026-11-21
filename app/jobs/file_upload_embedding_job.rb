# Stores the SigLIP 2 embedding of an uploaded image for semantic search.
class FileUploadEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(file_upload_id)
    file_upload = FileUpload.find_by(id: file_upload_id)
    return unless file_upload
    return unless Setting.find_by(name: 'image_description_analysis')&.formatted_value == true

    file_upload.store_embedding!
  end
end
