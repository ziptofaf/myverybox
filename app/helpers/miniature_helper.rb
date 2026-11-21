module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.upload.blob
    if blob.content_type.include?('image')
      thumbnail = image_tag blob.representation(resize_and_pad: [256, 256]).processed.url, class: 'ui small image'
      tag.div(thumbnail + hover_preview_for(blob), class: 'hover-preview')
    elsif blob.content_type.include?('video') && blob.previewable?
      image_tag blob.preview(resize: "256x256").processed.url, class: 'ui small image'
    end
  end

  private

  # Larger version shown when hovering the thumbnail. Uses the lazy
  # representation URL (processed on first request, not while rendering the
  # list) and loading="lazy", so nothing is generated or downloaded until the
  # preview is actually displayed.
  def hover_preview_for(blob)
    image_tag url_for(blob.representation(resize_to_limit: [1024, 1024])),
              class: 'hover-preview-image',
              loading: 'lazy',
              alt: blob.filename.to_s
  end
end