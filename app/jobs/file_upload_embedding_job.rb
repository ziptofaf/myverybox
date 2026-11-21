# Stores the SigLIP 2 embedding of an uploaded image for semantic search.
class FileUploadEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(file_upload_id)
    file_upload = FileUpload.find_by(id: file_upload_id)
    return unless file_upload
    return unless Setting.image_analysis_enabled?

    file_upload.store_embedding!
  end
end
