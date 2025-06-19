class ImageAnalysisService
  def initialize(file_upload)
    @file_upload = file_upload
  end
  
  def call
    return unless enabled?

    path = Settings.hostname + "/show/" + @file_upload.url
    res = HTTParty.get(Settings.image_analysis_hostname + "/?file_path=#{path}", timeout: 5)
    if res.code == 200
      @file_upload.update(description: res.body)
    end
  rescue Net::OpenTimeout, Errno::ECONNREFUSED # it's fine if it fails here, descriptions are optional
    # Ignored
  end
  
  private
  
  def enabled?
    Setting.find_by(name: 'image_description_analysis')&.formatted_value == true
  end
end