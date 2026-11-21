module UploadConversion
  # Image -> lossless PNG via ImageMagick: first frame/page only (HEIC
  # sequences, multi-page TIFF), EXIF orientation applied, colour profile kept.
  # HDR / gain-map data is not carried over.
  module ImageToPng
    def self.call(input_path)
      ImageProcessing::MiniMagick.source(input_path).loader(page: 0).convert('png').call
    rescue MiniMagick::Error, ImageProcessing::Error => e
      raise UploadConversion::Error, "#{e.class}: #{e.message}"
    end
  end
end
