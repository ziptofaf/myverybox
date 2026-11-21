class ApiKeysController < ApplicationController
  def index
    load_api_keys
    @api_key = ApiKey.new
  end

  # Renders the new key directly (no redirect), so the plaintext value is never
  # put into a URL, the flash/session or the browser cache. It cannot be shown
  # again afterwards - only its digest is stored.
  def create
    @api_key = current_user.api_keys.new(api_key_params)
    if @api_key.save
      response.headers['Cache-Control'] = 'no-store'
      render :created
    else
      load_api_keys
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    key = current_user.api_keys.find_by(id: params[:id])
    if key&.destroy
      redirect_to api_keys_path, notice: 'API key removed successfully'
    else
      redirect_to api_keys_path, notice: 'Could not remove API key'
    end
  end

  private

  def load_api_keys
    @api_keys = current_user.api_keys.order(created_at: :desc)
  end

  def api_key_params
    params.require(:api_key).permit(:description, :expires_in)
  end
end
