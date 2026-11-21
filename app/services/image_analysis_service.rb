class ImageAnalysisService
  def initialize(file_upload)
    @file_upload = file_upload
  end

  # Sends the image itself to the description service (POST, raw bytes) rather
  # than a public URL to fetch it from, so the service needs no route back to
  # this app (works the same inside docker compose, locally, and in production).
  def call
    return unless enabled?

    blob = @file_upload.display_blob
    return unless blob.content_type.to_s.start_with?('image/')

    res = HTTParty.post(
      Settings.image_analysis_hostname + "/",
      body: blob.download,
      headers: { 'Content-Type' => blob.content_type },
      timeout: 30
    )
    if res.code == 200
      @file_upload.update(description: res.body.encode("UTF-8", invalid: :replace, undef: :replace, replace: '?'))
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError # it's fine if it fails here, descriptions are optional
    # Ignored
  end

  private

  def enabled?
    Setting.image_analysis_enabled?
  end
end
