class Yahoo
  
  URL = 'http://search.yahooapis.com/VideoSearchService/V1/videoSearch'
  DEFAULTS = { :results => 6, :output => 'json', :type => 'any', :appid => 'SslWrfnV34Hza9jMJk98j87wBJ65IxayPSZxv.oQBvp.Tu5HKZgqUsee1JY5CjYi' }
  DEFAULT_OUTPUT = { :results => [], :yahoo => {} }
  ALLOWED_PARAMS = DEFAULTS
  
  def initialize(options={})
    @@options = DEFAULTS.merge(options)
  end
  
  def search(query,options={})
    output = DEFAULT_OUTPUT
    options = @@options.merge(options)
    begin
      json = Net::HTTP.get(URI.parse(query_path(query,options)))
      RAILS_DEFAULT_LOGGER.info("\n\nYAHOO RESPONSE\n"+json.to_s)   # log the response
      videos = ActiveSupport::JSON.decode(json)['ResultSet']['Result']

      unless videos.blank?
        output[:results] = videos.collect do |video|
          { :thumbnail => video['Thumbnail']['Url'],
            :title => video['Title'],
            :url => video['Url']}
        end
      end

    rescue => e
      # error with results
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH YAHOO RESPONSE: \n"+e.class.to_s+"\n"+e.message)   # log the response
    end

    return output
  end
   
  private 
  def query_path(query,options)
    output = URL + '?query=' + CGI::escape(query)
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
end