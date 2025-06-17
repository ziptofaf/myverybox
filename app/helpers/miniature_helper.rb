module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.upload.blob
    if blob.content_type.include?('image')
      image_tag blob.representation(resize_and_pad: [256, 256]).processed.url, class: 'ui small image'
    elsif blob.content_type.include?('video') && blob.previewable?
      image_tag blob.preview(resize: "256x256").processed.url, class: 'ui small image'
    end
  end
end