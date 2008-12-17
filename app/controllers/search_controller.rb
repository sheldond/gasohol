class SearchController < ApplicationController
  
  before_filter :login_required, :except => [:location] # this page is locked down, only accessible if logged in
  before_filter :get_location, :only => [:index, :home]  # get location from user cookie
  before_filter :get_options_from_query, :only => [:index, :google, :location] # format the query automatically for each request
  before_filter :check_skin, :only => [:index, :home]  # was there a skin defined?
  layout false  # most of the actions here are API calls, so by default we don't want a layout
  
  DO_RELATED_SEARCH = true  # do all the related (ajax) searches for each and every result
  DO_CONTEXT_SEARCH = true  # contextual search on the right
  DEBUG = false   # show timestamps for various processes at the bottom of the page (can show anyway by adding debug=true to URL)
  DEFAULT_LOCATION = 'San Diego,CA' # default location if geo-coding doesn't work
  
  @@gsa = ActiveSearch.new(GASOHOL_CONFIG[:google]) # instantiate an instance of gasohol (in this case our custom extension of it) as soon as this controller loads the first time
  
  # (/ or /search/home) 
  # homepage that just shows a search box and popular searches
  def home
    params[:q] ||= ''
    @popular_local_searches = Query.find_popular_by_location(@location,10)
    render :layout => 'application'
  end
  
  # (/search or /search/index)
  # This is where all the good stuff happens. Send the Google class the query (@query) and all the URL
  # variables (@options) and we'll format the results into a simpler format that we use in our views.
  def index
    params[:q] ||= ''
    
    @options.merge!({ :sort => 'date:A:S:d1'})  # default to sorting by date

    @time = {}
    @time[:google] = Time.now
      Query.record(@query,@options)
      @google = do_google
    @time[:google] = Time.now - @time[:google]
    
    @popular_local_searches = Query.find_popular_by_location(@location,5)   # most frequent keyword searches in same location
    @related_searches = Query.find_related_by_location(@query,@location,5)  # searches that contain the same keyword in the same location
    @month_separator_check = ''  # keeps track of what month is being shown in the results
    
    @ajax = ''
    
    render :layout => 'application'
  end
  
  # (/search/google)
  # API for getting Google results. Tack on .xml, .json, .yaml for various formats.
  # By default will output HTML formatted for our search results. Passing in ?style=short
  # to the HTML version will display the title only
  def google
    @google = do_google
    standard_response(@google)
  end
  
  # (/search/location)
  # API for access to the zips table. Takes a zip code and optional radius. Tack on .xml, .json, .yaml for various formats.
  # For the query string variables, 'zip' is required and 'radius' is optional.
  def location
    @result = []
    begin
      @result = Zip.find_within_radius(params[:zip],params[:radius])
    rescue => e
      RAILS_DEFAULT_LOGGER.error("\nERROR IN LOCATION\n"+e.class.to_s+"\n"+e.message)
    end
    standard_response(@result)
  end
  
  # (/search/set_location)
  # If called internally we pass a location object as 'value'. If no object was passed then look for a params[:value] instead.
  def set_location(value=nil)
    value ||= params[:value]
    if value.is_a?(String)
      begin
        @location = Location.new(value, { :radius => GASOHOL_CONFIG[:google][:default_radius] })
         cookies[:location] = { :value => @location.to_cookie, :expires => 1.year.from_now }
      rescue  # any problems then immediately error out
        render :text => "Please enter a valid city, state or zip"
        return
      end
    end
 
    # render the name of the location
    if request.xhr?
      output = "<strong>#{@location.form_value}</strong>"
      case @location.type
      when :everywhere
        render :text => output
      when :only_state
        render :text => "in #{output}"
      else
        render :text => "near #{output}"
      end
    end
    
  end
  
  private

  # Handles all the format types of the various API methods
  def standard_response(output)
   respond_to do |format|
      format.html
      format.xml  { render :xml => output.to_xml }
      format.json { render :text => output.to_json }
      format.yaml { render :text => output.to_yaml }
    end
  end
  
  # Actually does the work of calling the 'search' method of the Google class, passing in the query and options
  def do_google
    # TODO: some way to get the query recorded here -- but would run for all related searches as well
    # Maybe a flag you pass, defaulted to true, telling the system to record the query to the database
    
    # Query.record(@query,@options)
    @@gsa.search(@query, @options)
  end


  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def get_options_from_query
    @query = params[:q] || ''
    @options = {}
    
    # add in the user's location
    if @location
      case @location.type
      when :everywhere
        nil
      when :only_state
        @options.merge!({ :state => @location.state })
      else
        @options.merge!({ :latitude => @location.latitude, :longitude => @location.longitude, :radius => @location.radius })
      end
    end
      
    # put any other URL params into a hash as long as they're not the rails 
    # defaults (controller, action, format) or the query itself (that goes in @query)
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
  end
  
  # Get the location from either the query string, cookies or try to geo-locate
  def get_location
    
    if params[:location]    # if there's a location in the URL, use that above everything else
      @location = Location.new(params[:location], { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
    elsif cookies[:location]   # if there's a location cookie
      begin
        @location = Location.from_cookie(cookies[:location], { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      rescue
        # TODO: this is here in case the users have an 'old' cookie ... can remove after a couple months (added 12/17/08)
        @location = Location.new(DEFAULT_LOCATION)
        set_location(@location)
      end
    else  # otherwise try to geo-locate and either set the cookie to the result or set to a default location
      begin
        xml = Hpricot.XML(open('http://api.active.com/REST/Geotargeting/'+request.remote_addr))
        @location = Location.new((xml/:location).at('zip').innerHTML, { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      rescue # any kind of error with the request, set to San Diego, CA
        @location = Location.new(DEFAULT_LOCATION)
      end
      set_location(@location)
    end

  end
  
  # Checks if a skin is either in the query_string or a cookie
  def check_skin
    @skin = 'default'
    if params[:skin]
      cookies[:skin] = params[:skin]
      @skin = params[:skin]
    elsif cookies[:skin]
      @skin = cookies[:skin]
    end
  end
  
end
