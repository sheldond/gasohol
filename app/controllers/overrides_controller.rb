class OverridesController < ApplicationController
  # GET /overrides
  # GET /overrides.xml
  def index
    @overrides = Override.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @overrides }
    end
  end

  # GET /overrides/1
  # GET /overrides/1.xml
  def show
    @override = Override.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @override }
    end
  end

  # GET /overrides/new
  # GET /overrides/new.xml
  def new
    @override = Override.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @override }
    end
  end

  # GET /overrides/1/edit
  def edit
    @override = Override.find(params[:id])
  end

  # POST /overrides
  # POST /overrides.xml
  def create
    @override = Override.new(params[:override])

    respond_to do |format|
      if @override.save
        flash[:notice] = 'Override was successfully created.'
        format.html { redirect_to(@override) }
        format.xml  { render :xml => @override, :status => :created, :location => @override }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @override.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /overrides/1
  # PUT /overrides/1.xml
  def update
    @override = Override.find(params[:id])

    respond_to do |format|
      if @override.update_attributes(params[:override])
        flash[:notice] = 'Override was successfully updated.'
        format.html { redirect_to(@override) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @override.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /overrides/1
  # DELETE /overrides/1.xml
  def destroy
    @override = Override.find(params[:id])
    @override.destroy

    respond_to do |format|
      format.html { redirect_to(overrides_url) }
      format.xml  { head :ok }
    end
  end
end
