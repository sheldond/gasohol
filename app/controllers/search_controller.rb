class SearchController < ApplicationController
  
  before_filter :login_required, :except => [:location] # this page is locked down, only accessible if logged in
  before_filter :get_location, :only => [:index, :home, :google]  # get location from user cookie
  before_filter :format_query, :only => [:index, :google, :location] # format the query automatically for each request
  layout false  # most of the actions here are API calls, so by default we'll never want a layout
  
  DO_RELATED_SEARCH = false  # do all the related (ajax) searches for each and every result
  SHOW_TIMESTAMPS = true   # show timestamps for various processes at the bottom of the page (can show anyway by adding debug=true to URL)
  
  # instantiate an instance of the Google class as soon as this controller loads the first time
  @@gsa = ActiveSearch.new(GASOHOL_CONFIG['google'])
  
  # This is the default homepage that just shows a search box and popular searches
  def home
    @popular_local_searches = Query.find_popular_by_location(10, @location)
    render :layout => 'application'
  end

  # This is where all the good stuff happens. Send the Google class the query and all the URL
  # variables and we'll ask the GSA and format the results into a simpler format that we use in our views.
  def index
    params[:q] ||= ''
    # default to sorting by date
    # @options.merge!({ :sort => 'date:A:S:d1'})

    @time = {}
    @time[:all] = Time.now
    
    # google
    @time[:google] = Time.now
      Query.record(@query,@options)
      @google = do_google
    @time[:google] = Time.now - @time[:google]
    @time[:all] = Time.now - @time[:all]
    
    @popular_local_searches = Query.find_popular_by_location(5, @location)
    
    render :layout => 'application'
  end
  
  # API for getting Google results. Tack on .xml, .json, .yaml for various formats.
  # By default will output HTML formatted for our search results. Passing in ?style=short
  # to the HTML version will display the title only
  def google
    @google = do_google
    standard_response(@google)
  end
  
  # API for getting location data based on a zip code and optional radius. Tack on .xml, .json, .yaml for various formats.
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
  
  # Takes a ?value=abc query string variable and gets location data from the database. 'value' can be
  # either a city,state or zip code.
  def set_location(value=nil)
    # if we called this from elsewhere in the controller (rather than from a URL), used the passed value as the location
    value = value || params[:value]
    # if the value is already a valid location hash, just set it, this other crap isn't needed
    @location = value.is_a?(Hash) ? value : {}
    
    if value
      if @location.empty?     # if @location doesn't already contain a valid location Hash object
        zip = find_zip_from_string(value)
        unless zip.nil?
          ['zip','city','state','latitude','longitude'].each do |el|
            val = (el == 'state') ? { 'region' => State.find_by_name_or_abbreviation(zip.state).name.titlecase } : { el => zip.send(el).to_s.titlecase }
            @location.merge!(val)
          end
        end
      end
      # set the cookie
      cookies[:location] = { :value => @location.to_json, :expires => 1.year.from_now }
    else
      raise 'No location provided'
    end
    
    # only render something (the city, state of the current location) if this was called via ajax
    # otherwise be silent
    if request.xhr?
      unless @location.empty?
        render :text => "#{@location['city']}, #{@location['region']}"
      else
        render :text => "Please enter a valid city and state or zip"
      end
    end
    
  end
  
  private

  # Handles all the format options of the various API methods
  def standard_response(output)
   respond_to do |format|
      format.html
      format.xml { render :xml => output.to_xml }
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

  # Helper action that returns an ActiveRecord instance of the zip location for a passed zip or city,state
  def find_zip_from_string(text) 
    unless text.blank?
      if text.to_i > 0    # is this a zip code?
        zip = Zip.find_by_zip(text)
      else
        parts = text.split(',')
        # string contains a comma? if so, city and state
        if parts.length > 1
          city = text.split(',').first.strip
          state = State.find_by_name_or_abbreviation(text.split(',').last.strip)
          # TODO: shouldn't have to worry about case here
          if state
            zip = Zip.find_by_city_and_state(city.titlecase,state.abbreviation.upcase) # requires city name and 2-letter state abbreviation
          else
            raise "State '#{state}' not found"
          end
        else
          # otherwise assume this is a state
          # TODO: Write some logic to find the center-most zip in the state instead of the first one the database returns
          #       Also override the default location logic -- instead of worrying purely about radius we'll figure out the
          #       the optimal latitude/longitude numbers to use here and pass those on for the search
          zip = Zip.find_by_state(State.find_by_name_or_abbreviation(text.split(',').first.strip).abbreviation.upcase)
          unless zip
            raise "State '#{state}' not found"
          end
        end
      end
    else
      raise "No text provided to find zip from (ie: 92121 or 'san diego, ca')"
    end
    
    return zip
  end


  # Gets the query terms out of the query string and puts it in '@query'. Takes the remaining query string variables
  # and puts them into a hash called '@options'
  def format_query
    @query = params[:q] || ''
    @options = {}
    
    # add in the user's location
    if params[:location]
      zip = find_zip_from_string(params[:location])
      @options.merge!({ :latitude => zip.latitude, :longitude => zip.longitude })
    end
      
    # put any other URL params into a hash as long as they're not the rails 
    # defaults (controller, action, format) or the query itself (that goes in @query)
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
  end
  
  # Slightly confusing...due to the way Rails handles cookies, you can't set one and read it in the same
  # request. cookie[] represents the incoming cookies FROM the browser, cookie[]= sets the outgoing
  # cookies TO the browser. So, to get around this weird fact, if the cookie doesn't exist we create
  # it but don't rely on it existing to read back in -- we just set the @location variable directly 
  # and use it for this request. Future requests will see that the cookie exists, and that we haven't 
  # already set @location, and @location = cookie[:location]
  def get_location
  
    if cookies[:location].nil?
      @location = {}
      begin
        xml = Hpricot.XML(open('http://api.active.com/REST/Geotargeting/'+request.remote_addr))
        (xml/:location).each do |loc| 
          ['zip','city','region','latitude','longitude'].each do |el|
            @location.merge!({ el => loc.at(el).innerHTML.titlecase })
          end
        end
      rescue # any kind of error with the request, set to San Diego, CA
        set_location("San Diego,CA")
      end
      # assuming we found a location, set the cookie to it
      unless @location.empty?
        # cookies[:location] = @location.to_json
        set_location(@location)
      end
    end
  
    # if the cookie exists, and we didn't just find the location above, get it from the cookie
    if cookies[:location] && @location.nil?
      @location = ActiveSupport::JSON.decode(cookies[:location])
    end

  end
end
