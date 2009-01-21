class SearchController < ApplicationController
  # caches_page :google
  
  before_filter :login_required, :except => [:location,:google] # this page is locked down, only accessible if logged in
  before_filter :check_skin, :only => [:index, :home]  # was there a skin defined?
  layout false  # most of the actions here are API calls, so by default we don't want a layout
  
  DO_RELATED_SEARCH = true           # do all the related (ajax) searches for each and every result
  DO_CONTEXT_SEARCH = true           # contextual search on the right
  CONTEXT_RESULT_COUNT = 5            # number of items to show for contextual related
  DEFAULT_LOCATION = 'everywhere'     # default location if geo-coding doesn't work
  DEFAULT_SORT = 'relevance'          # default sort method
  SEARCH_MODES = [{:mode => 'activities', :name => 'Activities & Events' },
                  {:mode => 'results', :name => 'Race Results'},
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
    
    @sort = figure_sort
    if @sort == 'date'
      @do_date_separators = true
      google_sort_string = 'date:A:S:d1'
    else
      @do_date_separators = false
      google_sort_string = ''
    end

    # time how long it takes to hear back from the GSA
    @time = {}
    @time[:google] = Time.now
      @google = do_google(params,{:sort => google_sort_string})   # we manually pass in the sort so that ActiveSearch doesn't also need to do the figure_sort logic
    @time[:google] = Time.now - @time[:google]
    # TODO:  @google contains modified keywords/location that we update the database record with so we know what the search was transformed into
    # now update query record with the calculated values for keywords, location, etc.
    query_record.update_with_options(params)
    query_record.total_results = @google[:google][:total_results]
    query_record.user = current_user
    query_record.save
    
    # get various related queries on the page
    @location = Location.new!(params[:location] || 'everywhere')
    @popular_local_searches = Query.find_popular_by_location(@location,5)   # most frequent keyword searches in same location
    @related_searches = Query.find_related_by_location(params[:q],@location,5)  # searches that contain the same keyword in the same location
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
    google_sort_string = (figure_sort == 'date') ? 'date:A:S:d1' : ''     # what to sort by
    @google = do_google(params, {:sort => google_sort_string})
    standard_response(@google)
  end
  
  
  # (/search/related)
  # Does related item queries for every serach result on /search/index
  # Pass this a JSON array of hashes like so:  {id:1,calls:[{type:'google',name:'discussions',noun:'discussion',url:'http://site.com/search/google.json?asdf',link:'http://site.com'}]}
  # +id+    the id of result on the page that needs updating
  # +type+  one of google|photo|video|twitter
  # +name+  the name of the <div> to update in the view
  # +noun+  the name of the related 'thing' so we can singularize/pluralize the noun based on how many records were returned - "1 discussion" versus "3 discussions"
  # +ajax+  a URL that a browser could call to get the response it needs, ie. /search/google.json?q=marathon&mode=community&num=1&count_only=true, even though we're going to call it internally and only care about the query_string options
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
          result = do_google(get_options_from_url(call['ajax']))          # do_google already handles its own caching
        when 'photos'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['photos']['total'].to_i }
        when 'videos'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['feed']['openSearch$totalResults']['$t'].to_i }
        when 'tweets'
          result = cache(md5) { ActiveSupport::JSON.decode(Net::HTTP.get(URI.parse(call['ajax'])))['results'].length }
        end
        logger.debug("\n----\nResult from related call for #{call['type']}: #{result.inspect}\n------\n")
        if result.to_i == 0
          output << "$('result_#{request['id']}_links_#{call['name']}').remove();"
        else
          output << "$('result_#{request['id']}_links_#{call['name']}').insert({bottom:'<a href=\"#{call['link']}\">#{result} #{call['noun']}'+(#{result} != 1 ? 's' : '')+'</a>'});"
        end
      end      # cache
      # add an ajax call to un-hide the 'related' row on the page
      output << "!$('result_#{request['id']}_links').visible() ? $('result_#{request['id']}_links').show() : null;"
      js = output.join('')
    end
    # render all the calls and set content type so that we can evaluate them as valid statements in the browser
    render :text => js, :content_type => 'application/javascript'
  end
  

=begin  
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
=end  
  
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
        # TODO: why don't the above rescues work anymore?
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
    md5 = Digest::MD5.hexdigest(parts.inspect)
    return cache(md5) { SEARCH.search(parts,options) }
  end



  # Takes an optional URL and pulls parameters out of it instead of the default params hash
  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def get_options_from_url(url)
    options = {}
    CGI.parse(URI.parse(url).query).each { |key,value| options.merge!( {key.to_sym => value.first}) }
    logger.debug("\n\nSearchController: get_options_from_url: output=#{options.inspect}\n\n")
    return options
  end


  # Gets the location info out of the URL. If it isn't there then
=begin
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
=end
  
  # Used on the homepage so that the first time you come to the site we know where you are
  def get_or_set_default_location
    unless cookies[:location]
      xml = Hpricot.XML(open('http://api.active.com/REST/Geotargeting/'+request.remote_addr))
      location = Location.new!((xml/:location).at('zip').innerHTML, { :radius => params[:radius] || GASOHOL_CONFIG[:google][:default_radius] })
      # save to a cookie
      set_location(location)
    else
      location = Location.from_cookie(cookies[:location])
    end
    return location
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
    if !cookies[:sort] && !params[:sort] && params[:start_date] && !params[:start_date].empty?
      output = 'date'
    end
    
    # if nothing set the sort yet, default to relevance
    output ||= DEFAULT_SORT
    
    # at this point whatever we should sort by has been set as params[:sort] so just return it
    logger.debug("\n\nSearchController.figure_sort: Sorting by #{output}")
    return output
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