class SystemSettingsController < ApplicationController
  def index
    stats = StorageStats.new
    @database_bytes = stats.database_bytes
    @uploads = stats.uploads
    @disk = stats.disk
    @expires_in_seconds = Setting.find_by(name: 'expires_in_seconds')
    @remove_expired_files = Setting.find_by(name: 'remove_expired_files')
    @image_description_analysis = Setting.find_by(name: 'image_description_analysis')
    @cleanup_schedule = RecurringTaskStatus.for('clean_up_expired_uploads')
  end
  
  def update_settings
    @expires_in_seconds = Setting.find_by(name: 'expires_in_seconds')
    @remove_expired_files = Setting.find_by(name: 'remove_expired_files')
    @image_description_analysis = Setting.find_by(name: 'image_description_analysis')

    if permitted_params[:expires_in_seconds].present?
      @expires_in_seconds.update(value: permitted_params[:expires_in_seconds])
    end
    
    if permitted_params[:remove_expired_files].present?
      @remove_expired_files.update(value: permitted_params[:remove_expired_files])
    end

    if permitted_params[:image_description_analysis].present?
      @image_description_analysis.update(value: permitted_params[:image_description_analysis])
    end
    
    redirect_to system_settings_index_path, notice: 'Settings have been updated'
  end
  
  def clean_up_expired_file_uploads
    ExpiredUploadsCleanUpJob.perform_now(force: true)
    
    redirect_to system_settings_index_path, notice: 'Expired files have been removed'
  end
  
  def permitted_params
    params.require(:system_settings).permit(:expires_in_seconds, :remove_expired_files, :image_description_analysis)
  end
end