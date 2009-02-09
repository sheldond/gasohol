class SearchController < ApplicationController
  # caches_page :google
  
  before_filter :login_required, :except => [:location,:google]   # this page is locked down, only accessible if logged in
  before_filter :check_skin, :only => [:index, :home]             # was there a skin defined?
  layout false                                                    # most of the actions here are API calls, so by default we don't want a layout
  
  DO_RELATED_SEARCH = true           # do all the related (ajax) searches for each and every result
  MINI_RELEVANT_SEARCH_COUNT = 3      # number of results to show in the mini display of relevant results when the page is sorted by date
  DEFAULT_LOCATION = 'everywhere'     # default location if geo-coding doesn't work
  DEFAULT_SORT = 'relevance'          # default sort method
  DEFAULT_VIEW = 'enhanced'           # default view of results
  DEFAULT_MODE = 'activities'         # default mode (category to search in)
  SEARCH_MODES = [{:mode => 'activities', :name => 'Activities & Events' },
                  # {:mode => 'results', :name => 'Race Results'},
                  {:mode => 'training', :name => 'Training Plans'},
                  {:mode => 'articles', :name => 'Articles'},
                  {:mode => 'community', :name => 'Community'},
                  {:mode => 'orgs', :name => 'Clubs & Orgs'},
                  {:mode => 'facilities', :name => 'Facilities'}]
  LOCATION_AWARE_SEARCH_MODES = ['activities','orgs','facilities']    # search modes that display the location box
    
    
  # (/ or /search/home) 
  # homepage that just shows a search box and popular searches
  def home
    params[:q] ||= ''
    # what search mode are we in? default to activity search
    @mode = params[:mode] || DEFAULT_MODE; @mode.downcase!
    @view = figure_view
    cookies[:seen_view_notice] = 'true' unless cookies[:seen_view_notice]   # set a cookie so we don't keep showing the "how do you want to view your results?" box at the top right of the homepage
    
    # TODO: move popular searches into Ajax call so we can cache this page
    # TODO: move population of the 'Searching in' area to Ajax so we can cache
    @location = get_or_set_default_location
    @popular_local_searches = LOCATION_AWARE_SEARCH_MODES.include?(@mode) ? Query.find_popular_by_location_and_mode(@location,@mode,10) : Query.find_popular_by_mode(@mode,10)
    render :layout => 'application'
  end
  
  
  # (/search or /search/index)
  # This is where all the good stuff happens. Send the Google class the query (@query) and all the URL
  # variables (@options) and we'll format the results into a simpler format that we use in our views.
  def index    
    params[:q] ||= ''
    @mode = params[:mode] || DEFAULT_MODE; @mode.downcase!  # what search mode are we in? default to activity search
    @view = figure_view

    @sort = figure_sort
    if @sort == 'date'
      @do_date_separators = true
      google_sort_string = 'date:A:S:d1'
    else
      @do_date_separators = false
      google_sort_string = ''
    end
    
    # if user is sorting by date, do another search by relevance for the top 5 result
    if @sort == 'date'
      @mini_relevant_results = do_google(params.dup, {:num => MINI_RELEVANT_SEARCH_COUNT, :style => 'short', :sort => ''})
    end
    
    # do the real search we came here for
    @google = do_google(params.dup, {:sort => google_sort_string})   # we have to manually pass in the sort each time (instead of letting ActiveSearch figure it out) because sort could be based on cookie (which ActiveSearch can't read)
    
    # record this query to the database
    Query.new_search(params,@google.modified_params,{:total_results => @google.total_results, :user => current_user, :view => @view, :sort => @sort})
    
    # get various related queries on the page
    @location = Location.new!(params[:location])
    @popular_local_searches = LOCATION_AWARE_SEARCH_MODES.include?(@mode) ? Query.find_popular_by_location_and_mode(@location,@mode,5) : Query.find_popular_by_mode(@mode,5)
    @related_searches = LOCATION_AWARE_SEARCH_MODES.include?(@mode) ? Query.find_related_by_location_and_mode(@original_keywords,@location,@mode,5) : Query.find_related_by_mode(@original_keywords,@mode,5) # searches that contain the same keyword in the same location
    @month_separator_check = ''  # keeps track of what month is being shown in the results
    # @ajax = ''  # all of our ajax calls get saved up in this variable and output at the end of the page (so that all images can load before any of the Ajax calls go out)
    
    render :layout => 'application'
  end
  
  
  def debug
    
  end
  
  
  # (/search/google)
  # API for getting Google results. Tack on .xml, .json, .yaml for various formats.
  # By default will output HTML formatted for our search results. Some modifiers:
  # ?style=short     => Displays only the title of the result, not the full result with related queries and such
  # ?count_only=true => Returns only the count of total records, nothing else
  def google
    # we probably only want the keywords to location lookup if we're using the regular search front end
    # test_keywords_for_location!(params[:q])
    google_sort_string = (figure_sort == 'date') ? 'date:A:S:d1' : ''     # what to sort by
    @google = do_google(params, {:sort => google_sort_string, :skip_deep_keyword_search => true})
    standard_response(@google)
  end
  
  
  # does all of the related queries for a given event name and media types
  # URL to this call should look like:  /search/related?id=1&title=carlsbad+5000&media_types=5K|10K|Marathon
  # +id+ the id of the request as far as the browser is concerned so it can be replaced on the page
  # +title+ the title of the event
  # +media_types+ a pipe delimited list of media_types to search against
  def related
    key = md5('search/related/'+params.inspect)
    js = cache(key) do
      
      output = {:id => params[:id], :results => []}
      threads = []
    
      # discussions
      #threads << Thread.new do
        parts = { :q => params[:title], :mode => 'community' }
        begin
          value = do_google(parts, { :count_only => true, :skip_deep_keyword_search => true })
        rescue
          value = 0
        end
        output[:results] << { :name => 'discussions', :noun => 'discussion', :link => url_for(:controller => 'search', :action => 'index', :q => parts[:q], :mode => parts[:mode]), :value => value }
      #end
    
      # training plans
      #threads << Thread.new do 
        parts = { :q => '', :mode => 'training', :partialfields => '' }
        if params[:media_types].split('|').length > 0
          params[:media_types].split('|').each_with_index do |type,i|
            parts[:partialfields] += "mediaType:#{CGI::escape(type)}"
            parts[:partialfields] += '|' if params[:media_types].split('|').length-1 != i
          end
          begin
            value = do_google(parts, { :count_only => true, :skip_deep_keyword_search => true })
          rescue
            value = 0
          end
        else  # there were no mediaTypes so don't even try to pull training plans
          value = 0
        end
        output[:results] << { :name => 'training', :noun => 'training plan', :link => url_for(:controller => 'search', :action => 'index', :q => parts[:q], :mode => parts[:mode], :partialfields => parts[:partialfields]), :value => value }
      #end
    
      # articles
      #threads << Thread.new do
        parts = { :q => params[:title], :mode => 'articles' }
        begin
          value = do_google(parts, { :count_only => true, :skip_deep_keyword_search => true })
        rescue
          value = 0
        end
        output[:results] << { :name => 'articles', :noun => 'article', :link => url_for(:controller => 'search', :action => 'index', :q => parts[:q], :mode => parts[:mode]), :value => value }
      #end
    
      # photos
      #threads << Thread.new do
        begin
          value = ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse("http://api.flickr.com/services/rest?text=#{CGI::escape(params[:title])}&api_key=4998fab76787cf39383c563b32ce4b8f&method=flickr.photos.search&sort=relevance&format=json&nojsoncallback=1")))['photos']['total'].to_i
        rescue
          value = 0 
        end
      
        output[:results] << { :name => 'photos', :noun => 'photo', :link => "http://flickr.com/search/?w=all&m=text&q=#{CGI::escape(params[:title])}", :value => value }
     #end
    
      # videos
      #threads << Thread.new do
        begin
          value = ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse("http://gdata.youtube.com/feeds/api/videos?vq=#{CGI::escape(params[:title])}&max-results=1&alt=json")))['feed']['openSearch$totalResults']['$t'].to_i
        rescue
          value = 0
        end
        output[:results] << { :name => 'videos', :noun => 'video', :link => "http://www.youtube.com/results?search_query=#{CGI::escape(params[:title])}", :value => value }
      #end
    
      # tweets
      #threads << Thread.new do
        begin
          value = ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse("http://search.twitter.com/search.json?q=#{CGI::escape(params[:title])}")))['results'].length
        rescue
          value = 0
        end
        output[:results] << { :name => 'tweets', :noun => 'tweet', :link => "http://search.twitter.com/search?q=#{CGI::escape(params[:title])}", :value => value }
      #end
    
      #threads.each do |t| 
        #t.join
        #output[:results] << t.value
      #end
      
      output
    end

    render :text => js.to_json, :content_type => 'application/javascript'
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
        logger.info("\nSearchController. set_location: creating new location from string '#{value}'\n\n")
        location = Location.new(value, { :radius => GASOHOL_CONFIG[:google][:default_radius] })
      rescue Exceptions::LocationError::InvalidZip
        render :text => "Could not find zip - try city,state?", :status => 500
        return
      rescue Exceptions::LocationError::InvalidLocation
        render :text => "Please enter a valid city, state or zip", :status => 500
        return
      rescue
        render :text => "Please enter a valid city, state or zip", :status => 500
        return
      end
    end
    
    # if a location was found, set a cookie
    if location
      cookies[:location] = { :value => location.to_cookie, :expires => 1.year.from_now }
    end
 
    # render the name of the location
    render :text => location.display_value if request.xhr?
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
  
  
  # Actually does the work of searching the GSA, results are automatically cached
  def do_google(parts,options={})
    key = md5("#{parts.inspect}_#{options.inspect}")
    return cache(key) { SEARCH.search(parts,options) }
  end

  
  # Used on the homepage so that the first time you come to the site we know where you are
  def get_or_set_default_location
    unless cookies[:location]
      begin
        xml = Hpricot.XML(open('http://api.active.com/REST/Geotargeting/'+request.http_x_forwarded_for || request.remote_addr))
        location = Location.new!((xml/:location).at('zip').innerHTML, { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      rescue  # Location wasn't found
        location = Location.new!()
      end
      # save to a cookie
      set_location(location)
    else
      location = Location.from_cookie(cookies[:location])
    end
    return location
  end
  
  
  # Figure out what we should sort on based on various parameters
  def figure_sort
    if params[:mode] == 'activities'
      # if there's a 'sort' parameter in the URL it's because the user set it manually so save to cookie
      if params[:sort]
        cookies[:sort] = params[:sort]
        return params[:sort]
      end
    
      # because of the way cookies behave in Rails, we can't set and read in the same request, so if params[:sort]
      # doesn't exist then we didn't set a cookie this session, but if one does exist pull it back out to return
      if !params[:sort] && cookies[:sort]
        return cookies[:sort]
      end
    
      # should we automatically sort by date? (if the user doesn't have a cookie set, but they have chosen to filter by date, then yes)
      if !cookies[:sort] && !params[:sort] && params[:start_date] && !params[:start_date].empty?
        return 'date'
      end
    end
    
    # if nothing set the sort yet, default to relevance
    return DEFAULT_SORT
  end


  # Figure out what view to show, follows the same logic as figure_sort above
  def figure_view
    if params[:view]
      cookies[:view] = params[:view]
      return params[:view]
    end
  
    if !params[:view] && cookies[:view]
      return cookies[:view]
    end
    
    return DEFAULT_VIEW
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