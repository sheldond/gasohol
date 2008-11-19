class SearchController < ApplicationController
  
  before_filter :login_required
  before_filter :get_location, :only => [:index, :home, :google]
  before_filter :format_query, :except => [:get_location, :set_location]
  
  DO_RELATED_SEARCH = true
  SHOW_TIMESTAMPS = false   # show timestamps for API calls at the bottom of the page (can show anyway by adding debug=true to URL)
  DEFAULT_QUERY = 'active'
  # RESULTS_PER_PAGE = 25
  SPORTS = ['Baseball','Basketball','Cycling','Fitness &amp; Nutrition','Football','Golf','Mind &amp; Body','Outdoors','Running','Soccer','Softball','Tennis','Travel','Triathlon','Women','Others']
  CATEGORIES = ['Activities','Articles','eteamz Sites','Facilities','Organizations','People','Products','Videos']
  TYPES = ['Camp','Class','Conference','Event','Membership','Program','Tee Time','Tournament']
  
  @@google = Google.new
  @@twitter = Twitter.new
  @@flickr = Flickr.new
  @@yahoo = Yahoo.new
  
  layout false
  
  def home
    render :layout => 'application'
  end

  def index
    params[:q] ||= ''
    threads = []
    
    @time = {}
    @time[:all] = Time.now
    threads << Thread.new do
      @time[:google] = Time.now
      @google = do_google
      # if there were any sort params, sort the results by them
      @google[:results] = case params[:sort]
      when 'name'
        @google[:results].sort_by do |result|
          result[:title]
        end
      when 'date'
        @google[:results].sort_by do |result|
          result[:meta][:start_date]
        end
      #when 'location'
      #  @google[:results].sort_by do |result|
      #    result[:meta][:state]
      #  end
      when 'rating'
        @google[:results].sort_by do |result|
          result[:rating]
        end.reverse
      else
        @google[:results]
      end
      @time[:google] = Time.now - @time[:google]
    end
    
    # twitter
    threads << Thread.new do
      @time[:twitter] = Time.now
      @tweets = do_twitter              # @tweets = {:results => []}              # if we need to disable tweets
      @time[:twitter] = Time.now - @time[:twitter]
    end
    
    # flickr
    threads << Thread.new do
      @time[:flickr] = Time.now
      @flickr = do_flickr
      @time[:flickr] = Time.now - @time[:flickr]
    end
    
    # yahoo video
    threads << Thread.new do
      @time[:yahoo] = Time.now
      @yahoo = do_yahoo
      @time[:yahoo] = Time.now - @time[:yahoo]
    end
    
    # wait for all the threads to finish
    threads.each { |t| t.join }
    @time[:all] = Time.now - @time[:all]
    
    render :layout => 'application'
  end
  
  def google
    @google = do_google
    standard_response(@google)
  end
  
  def twitter
    @result = do_twitter
    standard_response(@result)
  end
  
  def flickr
    @result = do_flickr
    standard_response(@result)
  end
  
  def yahoo
    @result = do_yahoo
    standard_response(@result)
  end
  
  def location
    @result = []
    begin
      @result = Zip.find_within_radius(params[:zip],params[:radius])
    rescue => e
      RAILS_DEFAULT_LOGGER.error("\nERROR IN LOCATION\n"+e.class.to_s+"\n"+e.message)
    end
    standard_response(@result)
  end
  
  def set_location(value=nil)
    
    # if we called this from elsewhere in the controller (rather than from a URL), used the passed value as the location
    params[:value] = value || params[:value]
    
    @location = {}
    if params[:value]
      
      if params[:value].to_i > 0    # is this a zip code?
        zip = Zip.find_by_zip(params[:value])
      else
        city = params[:value].split(',').first.strip
        state = params[:value].split(',').last.strip.downcase
        found_state = Google::STATES.find { |key,value| value == state }
        state = found_state ? found_state.first : state  # is this is a full state name, get the abbreviation instead
        zip = Zip.find_by_city_and_state(city.titlecase,state.upcase)
      end
      
      unless zip.nil?
        ['zip','city','state','latitude','longitude'].each do |el|
          val = (el == 'state') ? { 'region' => Google::STATES[zip.send(el).downcase].titlecase } : { el => zip.send(el).to_s.titlecase }
          @location.merge!(val)
        end
        cookies[:location] = @location.to_json
      end
      
    else
      raise 'No location provided'
    end
    
    if request.xhr?
      # only render something (the city,state of the current location) if this was called via ajax
      unless @location.empty?
        render :text => "#{@location['city']}, #{@location['region']}"
      else
        render :text => "Please enter a valid zip code"
      end
    end
    
  end
  
  private
  def standard_response(output)
   respond_to do |format|
      format.html
      format.xml { render :xml => output.to_xml }
      format.json { render :text => output.to_json }
    end
  end
  
  def do_google
    @@google.search(@query, @options)
  end
  
  def do_twitter
    @@twitter.search(@query, @options)
  end
  
  def do_flickr
    @@flickr.search(@query, @options)
  end
  
  def do_yahoo
    @@yahoo.search(@query, @options)
  end

  def format_query
    @query = params[:q] || ''
    @options = {}
    
    # add in the user's location
    if params[:location]
      city = params[:location].split(',').first.strip
      state = params[:location].split(',').last.strip.downcase
      found_state = Google::STATES.find { |key,value| value == state }
      state = found_state ? found_state.first : state  # is this is a full state name, get the abbreviation instead
      zip = Zip.find_by_city_and_state(city.titlecase,state.upcase)
      @options.merge!({ :latitude => zip.latitude, :longitude => zip.longitude })
    end
      
    # put any other URL params into a hash as long as they're not the rails defaults (controller, action) 
    # or the query itself (that goes in @query)
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
  end
    
  #
  # Slightly confusing...due to the way Rails handles cookies, you can't set one and read it in the same
  # request. cookie[] represents the incoming cookies FROM the browser, cookie[]= sets the outgoing
  # cookies TO the browser. So, to get around this weird fact, if the cookie doesn't exist we create
  # it but don't rely on it existing to read back in -- we just set the @location variable directly 
  # and use it for this request. Future requests will see that the cookie exists, and that we haven't 
  # already set @location, and @location = cookie[:location]
  #

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
        # assuming we found a location, set it
        unless @location.empty?
          cookies[:location] = @location.to_json
        end
      end
    
      # if the cookie exists, and we didn't just find the location above, get it from the cookie
      if cookies[:location] && @location.nil?
        @location = ActiveSupport::JSON.decode(cookies[:location])
      end

  end
end
