class SessionController < ApplicationController

  layout 'users'

  def new
    log_out_user
    redirect_back if logged_in?
  end

  def create
    # if user is who they say they are, create their session - login
    unless params[:login].blank? or params[:password].blank?
      user = User.find_by_login_and_password(params[:login], params[:password])
      if user
        if user.is_banned
          flash[:notice] = 'You have been banned! You must have done something naughty. To appeal, email jeremy.thomas@active.com'
          render :action => 'new'
        elsif user.can_log_in or user.is_admin
          log_in_user(user)
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
    # remove user's session - logout
    log_out_user
    flash[:notice] = 'You have been logged out. Come back soon!'
    redirect_to login_path
  end
end
