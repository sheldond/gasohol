class SearchController < ApplicationController
  
  before_filter :login_required
  
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
  
  before_filter :format_query
  layout false
  
  def home
    render :layout => 'application'
  end

  def index
    params[:q] ||= ''
    threads = []
    
    @time = {}
    
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
      RAILS_DEFAULT_LOGGER.error("\nERROR IN LOCATION\n"+e.class.to_s+"\n"+e.message) if GASOHOL_DEBUGGING
    end
    standard_response(@result)
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
    @query = params[:q] || DEFAULT_QUERY
    @options = {}
    # put any other URL params into a hash as long as they're not the rails defaults (controller, action) or the query itself (that goes in @query)
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q' && key != 'format'
    end
  end

end
