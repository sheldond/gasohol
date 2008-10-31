class YouTube
  
  URL = GASOHOL_CONFIG['youtube']['url']
  DEFAULTS = { 'max-results' => GASOHOL_CONFIG['youtube']['results'], :alt => 'json' }
  DEFAULT_OUTPUT = { :results => [], :youtube => {} }
  ALLOWED_PARAMS = DEFAULTS
  
  def initialize(options={})
    @@options = DEFAULTS.merge(options)
  end
  
  def search(query,options={})
    output = DEFAULT_OUTPUT
    options = @@options.merge(options)
    begin
      json = Net::HTTP.get(URI.parse(query_path(query,options)))
      RAILS_DEFAULT_LOGGER.info("\n\nYOUTUBE RESPONSE\n"+json.to_s) if GASOHOL_DEBUGGING  # log the response
      videos = ActiveSupport::JSON.decode(json)['feed']['entry']
      unless videos.blank?
        output[:results] = videos.collect do |video|
          { :thumbnail => video['media$group']['media$thumbnail'][0]['url'],
            :title => video['media$group']['media$title']['$t'],
            :url => video['media$group']['media$player'][0]['url'].gsub(/\\u003d/,'=') }    # YouTube likes UTF equal signs
        end
      end
    rescue => e
      # error with results
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH YOUTUBE RESPONSE: \n"+e.class.to_s+"\n"+e.message)   # log the response
    end
    return output
  end
   
  private 
  def query_path(query,options)
    output = URL + '?vq=' + CGI::escape(query)
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
end