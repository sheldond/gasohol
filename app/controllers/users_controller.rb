class UsersController < ApplicationController
  
  before_filter :login_required, :except => [:new, :create]
  before_filter :admin_required, :except => [:new, :create]
  layout 'admin', :except => [:new, :create]
  
  def index
    @users = User.find(:all)
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    if logged_in? and !is_admin?
      redirect_to root_path # if they already have a user, and aren't an admin, they shouldn't be able to create a new user
    else
      @user = User.new
      @user.name, @user.email, @user.login, @user.password, @user.last_login_ip = ''
      render :layout => 'users'
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(params[:user])
    
    # has an invite code?
    if params[:code] && !params[:code].blank?
      invite = Invite.find_by_code(params[:code].downcase)
      if invite && invite.used < invite.available   # if the invite is valid and there are still some available
        invite.used += 1
        invite.last_used_at = Time.now.to_s(:db)
        invite.save
        @user.can_log_in = true
      else
        flash[:notice] = "Your invite code has expired or was invalid! We will email you an invite soon."
      end
    end
    
    if @user.save
      if is_admin?
        redirect_to users_path  # if you're admin go back to the admin list
      elsif @user.can_log_in
        log_in_user(@user)      # if you can log in (valid invite code), go ahead and log in automatically
        redirect_to root_path   # then go to the search homepage
      else
        render :action => 'thankyou', :layout => 'users'
      end
    else
      render :action => 'new', :layout => 'users'
    end
  end

  def update
    @user = User.find(params[:id])

    if @user.update_attributes(params[:user])
      flash[:notice] = 'User was successfully updated.'
      redirect_to(users_path)
    else
      render :action => "edit"
    end

  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
  
  def thankyou
    
  end
end
