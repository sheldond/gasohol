class QueriesController < ApplicationController
  
  before_filter :login_required, :admin_required
  layout 'admin'
  
  # GET /cities
  # GET /cities.xml
  def index
    if params[:count] == 'all'
      @queries = Query.find(:all)
    else
      @queries = Query.paginate(:page => params[:page], :order => 'id desc', :per_page => params[:count] || 50)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @queries }
      format.csv { render :layout => false }
    end
  end

end