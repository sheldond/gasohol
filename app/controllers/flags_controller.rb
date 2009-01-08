class FlagsController < ApplicationController
  
  before_filter :login_required
  before_filter :admin_required, :except => [:new, :create]
  
  def index
    @flags = Flag.find(:all)

    render :layout => 'admin'
  end


  def show
    @flag = Flag.find(params[:id])
    render :layout => 'admin'
  end


  def new
    @flag = Flag.new(:asset_id => params[:id], :user => current_user, :status => 'miscategorized')
    session[:return_to] = request.referer
  end


  def edit
    @flag = Flag.find(params[:id])
    render :layout => 'admin'
  end


  def create
    @flag = Flag.new(params[:flag])

    if @flag.save
      back = session[:return_to] || root_path
      session[:return_to] = nil
      flash[:notice] = "The event was flagged and we've been notified, thanks!"
      
      redirect_to(back)
    else
      render :action => "new"
    end

  end


  def update
    @flag = Flag.find(params[:id])

    respond_to do |format|
      if @flag.update_attributes(params[:flags])
        flash[:notice] = 'Flag was successfully updated.'
        redirect_to(@flag)
      else
        render :action => "edit"
      end
    end
  end


  def destroy
    @flag = Flag.find(params[:id])
    @flag.destroy

    redirect_to(flags_url)
  end
end
