class SearchController < ApplicationController
  # caches_page :google
  
  before_filter :login_required, :except => [:location,:google] # this page is locked down, only accessible if logged in
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
    @location = get_or_set_default_location
    @popular_local_searches = Query.find_popular_by_location(@location,10)
    render :layout => 'application'
  end
  
  # (/search or /search/index)
  # This is where all the good stuff happens. Send the Google class the query (@query) and all the URL
  # variables (@options) and we'll format the results into a simpler format that we use in our views.
  def index
    params[:q] ||= ''
    @do_date_separators = false
    
    # record original params as the query came in
    query_record = Query.new(:original_keywords => params[:q], :original_location => params[:location] || '')
    
    # did they type location-type things into the keywords box?
    test_keywords_for_location!(params[:q])
    
    # turn the query string parts into options that the GSA understands
    get_options_from_query
    
    # what should we sort by?
    @sort = figure_sort
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
    
    # time how long it takes to hear back from the GSA
    query_record.update_with_options(@query,@options)
    @time = {}
    @time[:google] = Time.now
      @google = do_google
    @time[:google] = Time.now - @time[:google]
    query_record.total_results = @google[:google][:total_results]
    query_record.user = current_user
    query_record.save
    
    # get various related queries on the page
    @location = get_location_from_params
    @popular_local_searches = Query.find_popular_by_location(@location,5)   # most frequent keyword searches in same location
    @related_searches = Query.find_related_by_location(@query,@location,5)  # searches that contain the same keyword in the same location
    @month_separator_check = ''  # keeps track of what month is being shown in the results
    
    # the result partials will populate this with related query ajax calls
    @ajax = ''
    
    render :layout => 'application'
  end
  
  # (/search/google)
  # API for getting Google results. Tack on .xml, .json, .yaml for various formats.
  # By default will output HTML formatted for our search results. Passing in ?style=short
  # to the HTML version will display the title only
  def google
    # we probably only want the keywords to location lookup if we're using the regular search front end
    # test_keywords_for_location!(params[:q])
    get_options_from_query
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
  # This method will always set a cookie, assuming a location was found
  def set_location(value=nil)    
    value ||= params[:value]
    
    if value.is_a?(Location)
      # this is already a valid Location object
      location = value
    elsif value.is_a?(String)
      # this is just a string, so try to parse it
      begin
        logger.info("\n\nset_location: creating new location from string #{value}\n\n")
        location = Location.new(value, { :radius => GASOHOL_CONFIG[:google][:default_radius] })
      rescue Exceptions::LocationError::InvalidZip
        render :text => "Could not find zip - try city,state?", :status => 500
        return
      rescue Exceptions::LocationError::InvalidLocation, Exceptions::LocationError::InvalidCityState
        render :text => "Please enter a valid city, state or zip", :status => 500
        return
      end
    end
    
    if location
      cookies[:location] = { :value => location.to_cookie, :expires => 1.year.from_now }
    end
 
    # render the name of the location
    if request.xhr?
      output = "<strong>#{location.form_value}</strong>"
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
      format.rss { render :content_type => 'application/rss+xml' }
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
        logger.debug("Search result cache HIT: #{md5}")
      else
        output = SEARCH.search(@query, @options)
        CACHE.set(md5, output, GASOHOL_CONFIG[:cache][:timeout])
        logger.debug("Search result cache MISS: #{md5}")
      end
    rescue MemCache::MemCacheError
      logger.error('Hitting CACHE failed: memcached server not running or not responding')
      output = SEARCH.search(@query, @options)
    end
    
    return output
  end
  
  
  # This gets a bang (!) because it will change params based on whether or not a location was found in the passed text string 
  def test_keywords_for_location!(text)
    
    # Try the whole keyword block first
    keywords = ''
    location = params[:q]
    begin
      found_location = Location.new(params[:q])
    rescue
    end
    
    # if the whole keyword didn't match, how about various parts of it?
    unless found_location
      if params[:q].split(' near ').length > 1
        keywords, location = params[:q].split(' near ')     # "running near atlanta, ga"
        begin
          found_location = Location.new(location)
        rescue
        end
      elsif params[:q].split(' in ').length > 1
        keywords, location = params[:q].split(' in ')       # "running in california"
        begin
          found_location = Location.new(location)
        rescue
        end
      elsif params[:q].split(' ').length > 1                # "running atlanta"  or  "running san diego"  but not  "running san diego, ca" (ca is the valid location, "running san diego" becomes the keywords)
        parts = params[:q].split(' ').reverse
        from = 0
        to = parts.length
        until from == to
          location = parts[0..from].reverse.join(' ')
          keywords = parts[from+1..to].reverse.join(' ')
          begin
            found_location = Location.new(location)
          rescue
          end
          break if found_location
          from += 1
        end
      end
    end
      
    # if it was found, reset the params
    if found_location
      params[:q] = keywords
      params[:location] = found_location.form_value
      logger.debug("Location found in keywords '#{params[:q]}'")
    end
  end
  
  
  # Figure out what we should sort on based on various parameters
  def figure_sort
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
    
    # at this point whatever we should sort by has been set as params[:sort] so just return it
    logger.debug("Sorting by #{params[:sort]}")
    return params[:sort]
  end


  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def get_options_from_query
    @query = params[:q] || ''
    @options = {}
    location = get_location_from_params
    
    # add in the user's location
    if params[:location]
      case location.type
      when :everywhere
        nil
      when :only_state
        @options.merge!({ :state => location.state })
      else
        @options.merge!({ :latitude => location.latitude, :longitude => location.longitude, :radius => location.radius })
      end
    end
      
    # put any other URL params into a hash as long as they're not the rails 
    # defaults (controller, action, format) or the query itself (that goes in @query)
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
  end


  # Gets the location info out of the URL. If it isn't there then
  def get_location_from_params
    if params[:location]
      return Location.new(params[:location], { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
    else
      return Location.new('everywhere')
    end
  end
  
  
  # Used on the homepage so that the first time you come to the site we know where you are
  def get_or_set_default_location
    unless cookies[:location]
      begin
        xml = Hpricot.XML(open('http://api.active.com/REST/Geotargeting/'+request.remote_addr))
        location = Location.new((xml/:location).at('zip').innerHTML, { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      rescue # any kind of error with the request, set to San Diego, CA
        location = Location.new(DEFAULT_LOCATION)
      end
      # save to a cookie
      set_location(location)
    else
      location = Location.from_cookie(cookies[:location])
    end
    return location
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