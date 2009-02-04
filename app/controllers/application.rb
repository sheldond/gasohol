# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  # before_filter :load_user
  # before_filter :adjust_format_for_iphone
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
  
  def current_user
    if logged_in?
      User.find(session[:user])
    end
  end
  
  def log_in_user(user)
    session[:user] = user.id
    user.last_login_at = Time.now
    user.last_login_ip = request.respond_to?('http_x_forwarded_for') ? request.http_x_forwarded_for : request.remote_addr
    user.save
  end
  
  def log_out_user
    session[:user] = nil
    cookies.delete :location
    cookies.delete :sort
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
    logged_in? and current_user.is_admin ? true : false
  end
  
  def redirect_back
    redirect_to(session[:return_to] || root_path)
    session[:return_to] = nil
  end
  
  def iphone_request?
    request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/(Mobile\/.+Safari)/]
  end
  
  # set default request format if request comes from an iphone
  def adjust_format_for_iphone    
    request.format = :iphone if iphone_request?
  end
  
  # Cache anything! Pass a block of what to cache if a lookup for passed +key+ isn't found. Usage:
  #   output = cache('foo') { 'hello, world' }
  # Looks for something in memcache with the +key+ 'foo' and returns it if found. If not found, then store 'hello, world' 
  # with the +key+ 'foo' and return to the caller. ie. +output+ will always equal the value of the block.
  def cache(key, &block)
    begin
      unless output = CACHE.get(key)
        output = yield
        CACHE.set(key, output, GASOHOL_CONFIG[:cache][:timeout])
        logger.info("Cache MISS and STORE: #{key}")
      else
        logger.info("Cache HIT: #{key}")
      end
    rescue MemCache::MemCacheError
      output = yield
      logger.info("Cache ERROR: Cache not available or not responding")
    end
    return output
  end
  
  # just says whether the given key is cached or not
  def is_cached?(text)
    return CACHE.get(text) ? true : false
  end
  
  
end
