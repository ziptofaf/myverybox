module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.upload.blob
    if blob.content_type.include?('image')
      image_tag blob.representation(resize_to_limit: [128, 128]).processed.url, class: 'ui mini image'
    else
      ''
    end
  end
end