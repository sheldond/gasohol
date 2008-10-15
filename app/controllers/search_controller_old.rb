class SearchController < ApplicationController
  
  RESULTS_PER_PAGE = 25
  SPORTS = ['Baseball','Basketball','Cycling','Fitness &amp; Nutrition','Football','Golf','Mind &amp; Body','Outdoors','Running','Soccer','Softball','Tennis','Travel','Triathlon','Women','Others']
  CATEGORIES = ['Activities','Articles','eteamz Sites','Facilities','Organizations','People','Products','Videos']
  TYPES = ['Camp','Class','Conference','Event','Membership','Program','Tee Time','Tournament']
  @@google = Google2.new('http://gsa7.enterprisedemo-google.com/search', :num => RESULTS_PER_PAGE)
  @@twitter = Twitter.new
  @@flickr = Flickr.new
  @@youtube = YouTube.new
  
  before_filter :format_query
  layout false

  def index
    @time = {}
    @time[:google] = Time.now
    @response = google
    @time[:google] = Time.now - @time[:google]
    @time[:twitter] = Time.now
    @tweets = twitter
    @time[:twitter] = Time.now - @time[:twitter]
    @time[:flickr] = Time.now
    @flickr = flickr
    @time[:flickr] = Time.now - @time[:flickr]
    @time[:youtube] = Time.now
    @youtube = youtube
    @time[:youtube] = Time.now - @time[:youtube]
    render :layout => 'application'
  end
  
  def google
    @google = @@google.search(@query, @options)
    #respond_to do |format|
    #  format.html
    #  format.xml { render :xml => @google.to_xml }
    #  format.json { render :text => @google.to_json }
    #end
  end
  
  def twitter
    @tweets = @@twitter.search(@query, @options)
    #respond_to do |format|
    #  format.html
    #  format.xml { render :xml => @tweets.to_xml }
    #  format.json { render :text => @tweets.to_json }
    #end
  end
  
  def flickr
    @flickr = @@flickr.search(@query, @options)
    #respond_to do |format|
    #  format.html
    #  format.xml { render :xml => @flickr.to_xml }
    #  format.json { render :text => @flickr.to_json }
    #end
  end
  
  def youtube
    @youtube = @@youtube.search(@query, @options)
    #respond_to do |format|
    #  format.html
    #  format.xml { render :xml => @youtube.to_xml }
    #  format.json { render :text => @youtube.to_json }
    #end
  end
  
  private
  def format_query
    @query = params[:q] || 'active'
    @options = {}
    # put any other URL params into a hash as long as they're not the controller, action or query term
    params.each do |key,value|
      @options.merge!({ key.to_sym => value.to_s }) if key != 'controller' && key != 'action' && key != 'q'
    end
  end

end
