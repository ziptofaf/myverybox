class FileUploadsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show_via_url, :upload_via_api]
  def index
    @file_uploads = FileUpload.where(user_id: current_user.id)
  end

  def show
    @file_upload = FileUpload.find(params[:id])
    redirect_to rails_blob_path(@file_upload.upload, disposition: "inline")
    #send_data @file_upload.upload.download, filename: @file_upload.upload.filename.to_s, content_type: @file_upload.upload.content_type
  end

  def destroy
    FileUpload.find(params[:id]).destroy
    redirect_to file_uploads_path, notice: 'File has been deleted successfully'
  end

  def show_via_url
    @file_upload = FileUpload.find_by(url: params[:url])
    if @file_upload.present?
      send_data @file_upload.upload.download, filename: @file_upload.upload.filename.to_s, content_type: @file_upload.upload.content_type
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
  
  def upload_via_api
    api_key = ApiKey.active.find_by(value: params[:api_key])
    if api_key.present?
      # try uploading file
    else
      render json: {status: 'error'}, status: 403
    end
  end
end
