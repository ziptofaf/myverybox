module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.upload.blob
    if blob.content_type.include?('image')
      image_tag blob.representation(resize_and_pad: [256, 256]).processed.url, class: 'ui small image'
    else
      ''
    end
  end
end