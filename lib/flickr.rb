class Flickr

  URL = GASOHOL_CONFIG['flickr']['url']
  DEFAULTS = { :api_key => GASOHOL_CONFIG['flickr']['key'], :method => 'flickr.photos.search', :sort => 'relevance', :format => 'json', :per_page => 6, :nojsoncallback => 1 }
  DEFAULT_OUTPUT = { :results => [], :flickr => { } }
  ALLOWED_PARAMS = DEFAULTS
  
  def initialize(options={})
    @@options = DEFAULTS.merge(options)
  end
  
  def search(query,options={})
    output = DEFAULT_OUTPUT
    options = @@options.merge(options)
    begin
      json = Net::HTTP.get(URI.parse(query_path(query,options)))
      RAILS_DEFAULT_LOGGER.info("\n\nFLICKR RESPONSE\n\n"+json.to_s) if GASOHOL_DEBUGGING  # log the response
      flickr_photos = ActiveSupport::JSON.decode(json)['photos']['photo']
      output[:results] = flickr_photos.collect do |photo|
        { :thumbnail => "http://farm#{photo['farm']}.static.flickr.com/#{photo['server']}/#{photo['id']}_#{photo['secret']}_s.jpg",
          :title => photo['title'],
          :url => "http://flickr.com/photos/#{photo['owner']}/#{photo['id']}" }
      end
    rescue => e
      # error with results
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH FLICKR RESPONSE: \n"+e.class.to_s+"\n"+e.message)   # log the response
    end
    return output
  end
  
  private 
  def query_path(query,options)
    output = URL + '?tags=' + CGI::escape(query) 
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
  
end