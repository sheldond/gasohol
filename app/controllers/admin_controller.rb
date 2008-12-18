class AdminController < ApplicationController
  
  before_filter :login_required, :admin_required
  
  def index
  end

end
