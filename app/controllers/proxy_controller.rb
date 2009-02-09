# Lets us to Ajax calls from the browser to third party services. params[:proxy_uri] is the URL of the service.
# This outputs exactly what the other service returns
class ProxyController < ApplicationController
  
  def index 
    logger.info("\n\nProxy request to: #{params[:proxy_uri]}\n\n")
    key = md5(params[:proxy_uri])
    render :text => cache(key) { Net::HTTP.get(URI.parse(params[:proxy_uri])) }
  end
  
end