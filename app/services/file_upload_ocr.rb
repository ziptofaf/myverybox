class FileUploadOcr
  def initialize(file_upload)
    @file_upload = file_upload
  end
  
  def text
    path = ActiveStorage::Blob.service.send(:path_for, @file_upload.upload.key)
    RTesseract.new(path).to_s
  rescue => e
    ""
  end
end