class SessionController < ApplicationController

  def new
  end

  def create
    # if user is who they say they are, create their session
    unless params[:login].blank? or params[:password].blank?
      user = User.find_by_login_and_password(params[:login], params[:password])
      if user
        if user.can_log_in
          session[:user] = user.id
          redirect_back
        else
          flash[:notice] = 'Your inviation hasn\'t been sent yet! You should hear from us soon.'
          render :action => 'new'
        end
      else
        flash[:notice] = 'No user was found with that login and password'
        render :action => 'new'
      end
    else
      flash[:notice] = 'Please provide both a username and password'
      render :action => 'new'
    end
  end

  def destroy
    # remove user's session
    session[:user] = nil
    flash[:notice] = 'You have been logged out. Come back soon!'
    redirect_to login_path
  end
end
