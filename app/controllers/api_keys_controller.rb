class ApiKeysController < ApplicationController
  def index
    @api_keys = ApiKey.where(user_id: current_user.id)
  end
  
  def create
    if ApiKey.create(user_id: current_user.id)
      redirect_to api_keys_path, notice: 'API key added successfully'
    else
      redirect_to api_keys_path, error: 'Could not add API key'
    end
  end
  
  def destroy
    key = ApiKey.find_by(user_id: current_user.id, id: params[:id])
    if key.destroy
      redirect_to api_keys_path, notice: 'API key removed successfully'
    else
      redirect_to api_keys_path, notice: 'Could not destroy API key'
    end
  end
end