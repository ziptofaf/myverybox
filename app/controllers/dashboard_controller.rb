class DashboardController < ApplicationController
  skip_before_action :authenticate_user!
  def index
  end
  
  def not_found
  end
end
