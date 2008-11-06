class UsersController < ApplicationController
  
  before_filter :login_required, :except => [:new, :create]
  before_filter :admin_required, :except => [:new, :create]
  
  def index
    @users = User.find(:all)
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    if logged_in? and !is_admin?
      # if they already have a user, and aren't an admin, they shouldn't be able to create a new user
      redirect_to root_path
    else
      @user = User.new
      @user.name, @user.email, @user.login, @user.password, @user.last_login_ip = ''
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(params[:user])
    
    if @user.save
      # flash[:notice] = 'Your invitation has been accepted!'
      if is_admin?
        redirect_to users_path
      else
        render :action => 'thankyou'
      end
    else
      render :action => 'new'
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
