module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.upload.blob
    if blob.content_type.include?('image')
      image_tag file_upload.upload, class: 'ui mini image'
    else
      ''
    end
  end
end