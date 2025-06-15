class SystemSettingsController < ApplicationController
  def index
    @space_available = SystemSettings.new.space_available
  end
end