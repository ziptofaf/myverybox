class FileUploadsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show_via_url, :show_original_via_url, :upload_via_api]
  skip_before_action :verify_authenticity_token, only: [:upload_via_api]
  include ActiveStorage::SetCurrent
  PER_PAGE = 10
  # sortable columns of the uploads list (?sort=...&direction=asc|desc)
  SORT_COLUMNS = {
    'uploaded' => 'file_uploads.created_at',
    'size' => 'active_storage_blobs.byte_size'
  }.freeze

  def index
    scope = uploads_scope.left_joins(upload_attachment: :blob)
    paginate(sorted(scope))
  end

  def search
    @image_search_enabled = Setting.image_analysis_enabled?
  end

  def search_results
    scope = uploads_scope.joins(upload_attachment: :blob)
    if search_params[:created_at_from].present?
      scope = scope.where('file_uploads.created_at >= ?', search_params[:created_at_from])
    end

    if search_params[:created_at_to].present?
      scope = scope.where('file_uploads.created_at <= ?', search_params[:created_at_to])
    end

    if search_params[:filename].present?
      scope = scope.where('active_storage_blobs.filename ILIKE ?', contains(search_params[:filename]))
    end

    # matches the generated description as well as text found in the image (OCR)
    if search_params[:description].present?
      pattern = contains(search_params[:description])
      scope = scope.where('file_uploads.description ILIKE :q OR file_uploads.caption ILIKE :q', q: pattern)
    end

    # "What's in the image?" - ranks all embedded images by similarity to the
    # query (SigLIP 2), so these results are always ordered by relevance.
    # (ignored while image analysis is disabled, e.g. from an old bookmarked link)
    if search_params[:content].present? && Setting.image_analysis_enabled?
      @sorted_by_relevance = true
      query = ImageEmbeddingClient.new.for_text(search_params[:content])
      if query
        scope = scope.where.not(embedding: nil)
        paginate(scope.nearest_neighbors(:embedding, query.embedding, distance: 'cosine'), count_scope: scope)
      else
        flash.now[:error] = 'Searching by image content is unavailable right now (image analysis service unreachable).'
        paginate(scope.none)
      end
    else
      paginate(sorted(scope))
    end

    render "index"
  end

  def show
    @file_upload = FileUpload.find_by(user_id: current_user.id, id: params[:id])
    if @file_upload && @file_upload.active?
      attachment = @file_upload.display_attachment!
      send_upload(attachment)
    else
      render dashboard_not_found_path, status: 404
    end
  end

  def destroy
    FileUpload.find_by(user_id: current_user.id, id: params[:id]).destroy
    redirect_to file_uploads_path, notice: 'File has been deleted successfully'
  end

  def show_via_url
    @file_upload = FileUpload.find_by(url: params[:url])
    if @file_upload.present? && @file_upload.active?
      attachment = @file_upload.display_attachment!

      send_upload(attachment)
    else
      render dashboard_not_found_path, status: 404
    end
  end
  
  # The untouched upload, for formats that are served converted by default.
  def show_original_via_url
    @file_upload = FileUpload.find_by(url: params[:url])
    if @file_upload.present? && @file_upload.active?
      send_upload(@file_upload.upload.attachment, disposition: 'attachment')
    else
      render dashboard_not_found_path, status: 404
    end
  end

  def new
    @file_upload = FileUpload.new
  end
  
  def create
    @file_upload = FileUpload.new(file_upload_params.except(:expires_after))
    @file_upload.expires_after = expiry_from_form
    if @file_upload.expires_after.blank? && file_upload_params[:expires_in_seconds].blank?
      setting = Setting.find_by(name: 'expires_in_seconds')
      @file_upload.expires_in_seconds = setting.formatted_value if setting
    end
    @file_upload.user = current_user
    @file_upload.generate_url

    if invalid_expiry_entered?
      @file_upload.errors.add(:expires_after, 'is not a valid date and time')
      render :new, status: :unprocessable_content
    elsif @file_upload.save
      redirect_to file_uploads_path, notice: 'File uploaded successfully'
    else
      render :new, status: :unprocessable_content
    end
  end

  def upload_via_api
    api_key = ApiKey.authenticate(request.headers["HTTP_API_KEY"])
    if api_key.present?
      api_key.touch_last_used!
      @file_upload = FileUpload.new(api_file_upload_params)
      @file_upload.user = api_key.user
      if api_file_upload_params[:expires_in_seconds].blank? && api_file_upload_params[:expires_after].blank?
        setting = Setting.find_by(name: 'expires_in_seconds')
        if setting
          @file_upload.expires_in_seconds = setting.formatted_value
        end
      end
      if @file_upload.save
        payload = { status: 'ok', url: Settings.hostname + "/show/" + @file_upload.url }
        # url serves the converted copy for formats browsers can't show; the original stays available
        payload[:original_url] = "#{payload[:url]}/original" if @file_upload.conversion
        render json: payload
      else
        render json: { status: 'error', errors: @file_upload.errors.full_messages }, status: :unprocessable_content
      end
    else
      render json: {status: 'error'}, status: 403
    end
  end
  
  private

  # Content that browsers treat as active documents (HTML, SVG, XML, ...) is
  # sandboxed: it still renders, but cannot run scripts or act as this origin
  # (e.g. use the signed-in user's session). Rails' own Active Storage
  # routes avoid this by forcing a download; these links are meant to be
  # viewable in the browser, hence the CSP sandbox instead.
  ACTIVE_CONTENT_CSP = "sandbox; default-src 'none'; img-src data:; style-src 'unsafe-inline'".freeze

  def send_upload(attachment, disposition: 'inline')
    if ActiveStorage.content_types_to_serve_as_binary.include?(attachment.blob.content_type)
      response.headers['Content-Security-Policy'] = ACTIVE_CONTENT_CSP
    end

    send_file(
      ActiveStorage::Blob.service.path_for(attachment.key),
      filename: attachment.blob.filename.to_s,
      type: attachment.blob.content_type,
      status: :ok,
      disposition: disposition
    )
  end
  
  def search_params
    params.require(:search).permit(:created_at_from, :created_at_to, :filename, :description, :content)
  end

  def uploads_scope
    FileUpload.where(user_id: current_user.id).includes(upload_attachment: :blob, converted_attachment: :blob)
  end

  # Orders by the requested column (default: newest first); the id tie-breaker
  # keeps pages stable when several uploads share a size or timestamp.
  def sorted(scope)
    @sort = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : 'uploaded'
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    scope.order(Arel.sql("#{SORT_COLUMNS.fetch(@sort)} #{@direction}, file_uploads.id #{@direction}"))
  end

  # Sets @file_uploads to the requested page plus the numbers the view needs.
  # count_scope: same rows without ordering/custom selects (nearest_neighbors adds one).
  def paginate(scope, count_scope: scope)
    @per_page = PER_PAGE
    @total_count = count_scope.unscope(:order).count
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @file_uploads = scope.limit(@per_page).offset((@page - 1) * @per_page)
  end

  # The form's datetime-local value carries no time zone: interpret it in the
  # browser's zone (sent along as time_zone), falling back to the app's (UTC).
  def expiry_from_form
    raw = file_upload_params[:expires_after].to_s.strip
    # exactly what <input type="datetime-local"> submits; Time.zone.parse alone
    # is lenient and would turn e.g. "next tuesday" into today's midnight
    return nil unless raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)

    zone = ActiveSupport::TimeZone[params[:time_zone].to_s] || Time.zone
    zone.parse(raw)
  rescue ArgumentError
    nil
  end

  def invalid_expiry_entered?
    file_upload_params[:expires_after].present? && @file_upload.expires_after.nil?
  end

  # "%term%" with LIKE wildcards in the user's input escaped
  def contains(term)
    "%#{FileUpload.sanitize_sql_like(term.to_s)}%"
  end
  
  def file_upload_params
    params.require(:file_upload).permit(:expires_after, :upload, :expires_in_seconds)
  end
  
  def api_file_upload_params
    params.permit(:expires_after, :upload, :expires_in_seconds)
  end
end
