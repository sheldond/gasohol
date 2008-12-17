# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :load_user
  helper :all

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  # protect_from_forgery # :secret => 'f48b1e284a40a73fdb0599a88b686b6d'
  
  private
  def load_user
    if logged_in?
      @current_user = User.find(session[:user])
    end
  end
  
  def log_in_user(user)
    session[:user] = user.id
    user.last_login_at = Time.now
    user.last_login_ip = request.remote_addr
    user.save
  end
  
  def log_out_user
    session[:user] = nil
    cookies.delete :location
  end
  
  def login_required
    if !logged_in?
      session[:return_to] = request.request_uri
      redirect_to login_path
    end
  end
  
  def admin_required
    unless is_admin?
      redirect_to root_path
    end
  end
  
  def logged_in?
    !session[:user].nil?
  end
  
  def is_admin?
    logged_in? and @current_user.is_admin ? true : false
  end
  
  def redirect_back
    redirect_to(session[:return_to] || root_path)
    session[:return_to] = nil
  end
end
