class FileUploadsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show_via_url, :upload_via_api]
  skip_before_action :verify_authenticity_token, only: [:upload_via_api]
  def index
    @per_page = 10
    @page = params[:page].to_i || 1
    if @page == 0
      @page = 1
    end
    if @page == 1
      offset = 0
    else
      offset = (@page - 1) * @per_page
    end
    
    @file_uploads = FileUpload.includes(upload_attachment: :blob).order('id desc').where(user_id: current_user.id).limit(@per_page).offset(offset)
  end

  def show
    @file_upload = FileUpload.find(user_id: current_user.id, id: params[:id])
    redirect_to rails_blob_path(@file_upload.upload, disposition: "inline")
  end

  def destroy
    FileUpload.find_by(user_id: current_user.id, id: params[:id]).destroy
    redirect_to file_uploads_path, notice: 'File has been deleted successfully'
  end

  def show_via_url
    @file_upload = FileUpload.find_by(url: params[:url])
    if @file_upload.present?
      redirect_to rails_blob_path(@file_upload.upload, disposition: "inline")
    end
  end
  
  def new
    @file_upload = FileUpload.new
  end
  
  def create
    @file_upload = FileUpload.new(file_upload_params)
    @file_upload.user = current_user
    @file_upload.generate_url
    if @file_upload.save
      redirect_to file_upload_path(@file_upload), notice: 'File uploaded successfully'
    else
      render :new, error: 'Error uploading file'
    end
  end
  
  def file_upload_params
    params.require(:file_upload).permit(:expires_after, :upload)
  end
  
  def api_file_upload_params
    params.permit(:expires_after, :upload)
  end
  
  def upload_via_api
    api_key = ApiKey.active.find_by(value: request.headers["HTTP_API_KEY"])
    if api_key.present?
      @file_upload = FileUpload.new(api_file_upload_params)
      @file_upload.user = api_key.user
      @file_upload.generate_url
      if @file_upload.save
        render json: {status: 'ok', url: Settings.hostname + "/show/" + @file_upload.url}
      else
        render json: {status: 'error'}, status: 500
      end
    else
      render json: {status: 'error'}, status: 403
    end
  end
end
