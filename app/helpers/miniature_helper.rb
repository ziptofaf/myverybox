module MiniatureHelper
  def miniature_for(file_upload)
    blob = file_upload.display_blob
    if blob.content_type.to_s == 'image/svg+xml'
      # Active Storage refuses to transform SVGs (they can contain scripts).
      # Showing the file itself is safe in an <img>: browsers never run
      # scripts of images embedded this way.
      svg_miniature_for(file_upload)
    elsif blob.variable?
      thumbnail = image_tag blob.representation(resize_and_pad: [256, 256]).processed.url, class: 'ui small image'
      tag.div(thumbnail + hover_preview_for(blob), class: 'hover-preview')
    elsif blob.content_type.to_s.include?('video') && blob.previewable?
      image_tag blob.preview(resize: "256x256").processed.url, class: 'ui small image'
    end
  rescue ActiveStorage::Error, MiniMagick::Error, ActiveStorage::FileNotFoundError => e
    # One broken file must not take the whole listing down.
    Rails.logger.warn("No miniature for FileUpload##{file_upload.id}: #{e.class}: #{e.message}")
    nil
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

  def svg_miniature_for(file_upload)
    return unless file_upload.active?

    src = "/show/#{file_upload.url}"
    alt = file_upload.upload.blob.filename.to_s
    thumbnail = image_tag src, class: 'ui small image svg-miniature', alt: alt
    preview = image_tag src, class: 'hover-preview-image', loading: 'lazy', alt: alt
    tag.div(thumbnail + preview, class: 'hover-preview')
  end
end
