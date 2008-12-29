class SearchController < ApplicationController
  # caches_action :home
  
  before_filter :login_required, :except => [:location] # this page is locked down, only accessible if logged in
  before_filter :get_location, :only => [:index, :home]  # get location from user cookie
  before_filter :get_options_from_query, :only => [:index, :google, :location] # format the query automatically for each request
  before_filter :check_skin, :only => [:index, :home]  # was there a skin defined?
  layout false  # most of the actions here are API calls, so by default we don't want a layout
  
  DO_RELATED_SEARCH = true  # do all the related (ajax) searches for each and every result
  DO_CONTEXT_SEARCH = true  # contextual search on the right
  DEBUG = false   # show debugging at the bottom of the page (can show anyway by adding debug=true to URL)
  DEFAULT_LOCATION = 'San Diego,CA' # default location if geo-coding doesn't work
  DEFAULT_SORT = 'relevance'  # default sort method
    
  # (/ or /search/home) 
  # homepage that just shows a search box and popular searches
  def home
    params[:q] ||= ''
    # TODO: move popular searches into Ajax call so we can cache this page
    # TODO: move population of the 'Searching in' area to Ajax so we can cache
    @popular_local_searches = Query.find_popular_by_location(@location,10)
    render :layout => 'application'
  end
  
  # (/search or /search/index)
  # This is where all the good stuff happens. Send the Google class the query (@query) and all the URL
  # variables (@options) and we'll format the results into a simpler format that we use in our views.
  def index
    params[:q] ||= ''
    @do_date_separators = false
    
    # what should we sort by?
    @sort = do_sort
    if @sort == 'date'
      @options.merge!( {:sort => 'date:A:S:d1'} )
      @do_date_separators = true
    end
    
    # Sometimes we want to override the user's filter settings if they did a simple keyword search
    # but we think we can get better results by injecting some extra pizzaz into the query to the GSA
    if simple_search?(@options)
      if @override = Override.find_by_keywords(@query)
        @options.merge!(@override.to_options)
      end
    end

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
      rescue Exceptions::LocationError::InvalidZip
        render :text => "Could not find zip - try city,state?", :status => 500
        return
      rescue Exceptions::LocationError::InvalidLocation, Exceptions::LocationError::InvalidCityState
        render :text => "Please enter a valid city, state or zip", :status => 500
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
  
  # Actually does the work of searching the GSA
  def do_google
    # TODO: some way to get the query recorded here -- but would run for all related searches as well
    # Maybe a flag you pass, defaulted to true, telling the system to record the query to the database
    # caching time
    begin
      md5 = Digest::MD5.hexdigest("#{request.path_info}?#{@query.to_s}_#{@options.to_s}")
      if output = CACHE.get(md5) 
        logger.debug("Search result cache hit: #{md5}")
      else
        output = SEARCH.search(@query, @options)
        CACHE.set(md5, output, 4.hours)
        logger.debug("Search result cache miss: #{md5}")
      end
    rescue MemCache::MemCacheError
      logger.error('Hitting CACHE failed: memcached server not running or not responding')
      output = SEARCH.search(@query, @options)
    end
    
    return output
  end
  
  # Figure out what we should sort on based on various parameters
  def do_sort
    # if there's a 'sort' parameter in the URL it's because the user set it manually so save to cookie
    if params[:sort]
      cookies[:sort] = params[:sort]
    end
    
    # because of the way cookies behave in Rails, we can set and read in the same request, so if params[:sort]
    # doesn't exist then we didn't set a cookie this session, but if one does exist pull it back out and set it
    # to params[:sort] so that it's the only thing we have to worry about in the checks below
    if !params[:sort] && cookies[:sort]
      params[:sort] = cookies[:sort]
    end
    
    # should we automatically sort by date? (if the user doesn't have a cookie set, but they have chosen to filter by date, then yes)
    if !params[:sort] && @options[:start_date] && !@options[:start_date].empty?
      params[:sort] = 'date'
    end
    
    # if nothing set the sort yet, default to relevance
    params[:sort] ||= DEFAULT_SORT
    
    # sort by date if - it's in the URL of if there's a cookie stored
    return params[:sort]

  end


  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def get_options_from_query
    @query = params[:q] || ''
    @options = {}
    
    # add in the user's location
    if params[:location]
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
  
  # Determines whether this is search that uses only keywords
  def simple_search?(options)
    (options[:category] && options[:category].downcase == 'activities') && (options[:sport].nil? || options[:sport].downcase == 'any') && (options[:type].nil? || options[:type].downcase == 'any') && (options[:custom].nil? || options[:custom].downcase == 'any')
  end
  
end
