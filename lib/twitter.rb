class Twitter
  
  URL = GASOHOL_CONFIG['twitter']['url']
  DEFAULTS = {}
  DEFAULT_OUTPUT = { :results => [], :twitter => {} }
  ALLOWED_PARAMS = DEFAULTS
  
  def initialize(options={})
    @@options = DEFAULTS.merge(options)
  end
  
  def search(query,options={})
    output = DEFAULT_OUTPUT
    options = @@options.merge(options)
    begin
      json = Net::HTTP.get(URI.parse(query_path(query, options)))
      RAILS_DEFAULT_LOGGER.info("\n\nTWITTER RESPONSE\n\n"+json.to_s)  if GASOHOL_DEBUGGING  # log the response
      tweets = ActiveSupport::JSON.decode(json)['results']
      output[:results] = tweets.collect do |tweet|
        query.split(' ').each do |word|
          tweet['text'].gsub!(/(#{word})/i,'<strong>\1</strong>')        # bold any instances of the search string in the tweet
        end
        tweet['text'].gsub!(/(http.*?)(\s|$)/i, '<a href="\1">\1</a>')   # make any links clickable
        tweet
      end
    rescue => e
      # error with results
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH TWITTER RESPONSE: \n"+e.class.to_s+"\n"+e.message)   # log the response
    end
    return output
  end
  
  private 
  def query_path(query,options)
    output = URL + '?q=' + CGI::escape(query)
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
  
end