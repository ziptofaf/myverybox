# Browser-friendly copies of uploads in formats browsers can't (reliably) show.
#
# This is the one place that decides what gets converted and how. When an
# upload matches a rule, a converted copy is stored next to the original and
# used everywhere by default: share links / API URLs, thumbnails,
# descriptions, OCR and image search. The untouched original stays
# downloadable via /show/<url>/original.
#
# To support another kind of conversion, add a Rule with a converter: any
# object responding to `call(input_path)` that returns a Tempfile with the
# result (raising UploadConversion::Error on failure). For example, later:
#
#   Rule.new(name: 'Video to H.264',
#            from: %w[video/quicktime video/x-matroska],
#            to: 'video/mp4', extension: 'mp4',
#            converter: UploadConversion::VideoToH264,
#            on_demand: false) # minutes, not seconds: never block a request on it
module UploadConversion
  class Error < StandardError; end

  # on_demand: may a request (e.g. opening a share link right after an API
  # upload) wait for the conversion if the background job hasn't finished?
  # Otherwise the original is served until the copy exists.
  Rule = Data.define(:name, :from, :to, :extension, :converter, :on_demand) do
    def on_demand? = on_demand
  end

  RULES = [
    # Lossless, so the result is "just a picture". Not listed on purpose:
    # AVIF, WebP, BMP, ICO (all current browsers show them), GIF (would lose
    # animation), SVG (served sandboxed), JPEG XL (bundled ImageMagick can't
    # read it) and camera RAW (needs real "developing", not a plain conversion).
    Rule.new(
      name: 'Image to PNG',
      from: %w[
        image/heic image/heif image/heic-sequence image/heif-sequence
        image/tiff
        image/vnd.adobe.photoshop
        image/jp2
        image/x-tga
        image/x-portable-anymap image/x-portable-bitmap image/x-portable-graymap image/x-portable-pixmap
      ],
      to: 'image/png', extension: 'png',
      converter: UploadConversion::ImageToPng,
      on_demand: true
    )
  ].freeze

  # The rule for a content type, or nil when no conversion is needed.
  def self.for(content_type)
    RULES.find { |rule| rule.from.include?(content_type.to_s) }
  end
end
