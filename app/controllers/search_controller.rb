class SearchController < ApplicationController
  # caches_page :google
  
  before_filter :login_required, :except => [:location,:google] # this page is locked down, only accessible if logged in
  before_filter :check_skin, :only => [:index, :home]  # was there a skin defined?
  layout false  # most of the actions here are API calls, so by default we don't want a layout
  
  DO_RELATED_SEARCH = true          # do all the related (ajax) searches for each and every result
  DO_CONTEXT_SEARCH = true          # contextual search on the right
  CONTEXT_RESULT_COUNT = 5          # number of items to show for contextual related
  DEFAULT_LOCATION = 'everywhere'   # default location if geo-coding doesn't work
  DEFAULT_SORT = 'relevance'        # default sort method
    
  # (/ or /search/home) 
  # homepage that just shows a search box and popular searches
  def home
    params[:q] ||= ''
    # what search mode are we in? default to activity search
    @mode = params[:mode] || 'activities'
    
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
    
    # what search mode are we in? default to activity search
    @mode = params[:mode] || 'activities'

    # record original params as the query came in
    query_record = Query.new_with_original_params(params)
    
    # did they type location-type things into the keywords box?
    test_keywords_for_location!(params[:q])
    
    # turn the query string parts into options that the GSA understands
    @query, @options = get_options_from_query
    
    @do_date_separators = false
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
    
    # now update query record with the calculated values for keywords, location, etc.
    query_record.update_with_options(@query,@options)
    
    # time how long it takes to hear back from the GSA
    @time = {}
    @time[:google] = Time.now
      @google = do_google(@query,@options)
    @time[:google] = Time.now - @time[:google]
    query_record.total_results = @google[:google][:total_results]
    query_record.user = current_user
    query_record.save
    
    # get various related queries on the page
    @location = get_location_from_params(params)
    @popular_local_searches = Query.find_popular_by_location(@location,5)   # most frequent keyword searches in same location
    @related_searches = Query.find_related_by_location(@query,@location,5)  # searches that contain the same keyword in the same location
    @month_separator_check = ''  # keeps track of what month is being shown in the results
    
    # the result partials will populate this with related query ajax calls and then output at the end of the page
    @ajax = ''
    
    render :layout => 'application'
  end
  
  # (/search/google)
  # API for getting Google results. Tack on .xml, .json, .yaml for various formats.
  # By default will output HTML formatted for our search results. Some modifiers:
  # ?style=short     => Displays only the title of the result, not the full result with related queries and such
  # ?count_only=true => Returns only the count of total records, nothing else
  def google
    # we probably only want the keywords to location lookup if we're using the regular search front end
    # test_keywords_for_location!(params[:q])
    @query, @options = get_options_from_query
    @google = do_google(@query,@options)
    standard_response(@google)
  end
  
  
  # (/search/related)
  # Does related item queries for every serach result on /search/index
  # Pass this a JSON array of hashes like so:  {id:1,calls:[{type:'google',name:'discussions',noun:'discussion',url:'http://site.com/search/google.json?asdf',link:'http://site.com'}]}
  # +id+    the id of result on the page that needs updating
  # +type+  one of google|photo|video|twitter
  # +name+  the name of the <div> to update in the view
  # +noun+  the name of the related 'thing' so we can singularize/pluralize the noun based on how many records were returned - "1 discussion" versus "3 discussions"
  # +ajax+  where to go to get the response
  # +link+  link that the user can click to see the full result set
  def related
    # only if this entire request is not cached will we look at each individual part (and also see if THEY'RE cached)
    md5 = Digest::MD5.hexdigest(params[:request])
    js = cache(md5) do
      request = ActiveSupport::JSON.decode(params[:request])
      output = []
      request['calls'].each do |call|
        md5 = Digest::MD5.hexdigest(call['ajax'])
        # TODO: Thread these
        case call['type']
        when 'google'
          query,options = get_options_from_query(call['ajax'])
          result = do_google(query,options)             # do_google already handles its own caching
        when 'photos'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['photos']['total'] }
        when 'videos'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['feed']['openSearch$totalResults']['$t'] }
        when 'tweets'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['results'].length }
        end
        if result.to_i == 0
          output << "$('result_#{request['id']}_links_#{call['name']}').remove();"
        else
          output << "$('result_#{request['id']}_links_#{call['name']}').insert({bottom:'<a href=\"#{call['link']}\">#{result} #{call['noun']}'+(#{result} != 1 ? 's' : '')+'</a>'});"
        end
      end
      # add an ajax call to un-hide the 'related' row on the page
      output << "!$('result_#{request['id']}_links').visible() ? $('result_#{request['id']}_links').show() : null;"
      js = output.join('')
    end
    # render all the calls and set content type so that we can evaluate them as valid statements in the browser
    render :text => js, :content_type => 'application/javascript'
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
      rescue Exceptions::LocationError::InvalidLocation, Exceptions::LocationError::InvalidCityState
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
  def do_google(query,options)
    md5 = Digest::MD5.hexdigest("#{query.to_s}_#{options.to_s}")
    return cache(md5) { SEARCH.search(query,options) }
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
        parts = params[:q].split(' ').reverse               # Starting from the end of multiple keywords, check if the last word is a valid location, if not then add the second to last word to the string and check that, etc.
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
      logger.debug("SearchController.test_keywords_for_location: Location found in keywords '#{params[:q]}'")
    end
  end
  
  
  # Figure out what we should sort on based on various parameters
  def figure_sort
    output = nil
    
    # if there's a 'sort' parameter in the URL it's because the user set it manually so save to cookie
    if params[:sort]
      cookies[:sort] = params[:sort]
      output = params[:sort]
    end
    
    # because of the way cookies behave in Rails, we can't set and read in the same request, so if params[:sort]
    # doesn't exist then we didn't set a cookie this session, but if one does exist pull it back out to return
    if !params[:sort] && cookies[:sort]
      output = cookies[:sort]
    end
    
    # should we automatically sort by date? (if the user doesn't have a cookie set, but they have chosen to filter by date, then yes)
    if !cookies[:sort] && !params[:sort] && @options[:start_date] && !@options[:start_date].empty?
      output = 'date'
    end
    
    # if nothing set the sort yet, default to relevance
    output ||= DEFAULT_SORT
    
    # at this point whatever we should sort by has been set as params[:sort] so just return it
    logger.debug("\n\nSearchController.figure_sort: Sorting by #{output}")
    return output
  end


  # Takes an optional URL and pulls parameters out of it instead of the default params hash
  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def get_options_from_query(url='')
    unless url == ''
      # turn the passed url into a set of query params to simulate the standard params hash from Rails
      p = {}
      CGI.parse(URI.parse(url).query).collect { |key,value| p[key.to_sym] = value.join('') }
    else
      p = params
    end

    query = p[:q] || ''
    options = {}

    # put any other URL params into a hash as long as they're not the rails 
    # defaults (controller, action, format) or the query itself (that goes in @query)
    p.each do |key,value|
      options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
    
    return [query,options]
  end


  # Gets the location info out of the URL. If it isn't there then
  def get_location_from_params(p)
    begin
      if p[:location]
        return Location.new(p[:location], { :radius => p[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      else
        return Location.new('everywhere')
      end
    rescue  #problem with the location in the URL, just search everywhere
      logger.info("\n\nSearchController.get_location_from_params: Location in URL is bogus: '#{params[:location]}\n\n")
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