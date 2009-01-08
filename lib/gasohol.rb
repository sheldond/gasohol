# = Introduction
# Gasohol lets you query a Google Search Appliance and get results back in an easily traversable format.
# 
# == Terms
# Let's get some nomenclature out of the way. It's a little confusing when we talk about 'query' in
# a couple of different ways.
#
# There are two parts to a Google GSA request:
#
# 1. query (search terms)
# 2. options (stuff like 'collection,' client,' and 'num')
#
# And then there is the actual string that you see in your browser, the "query string," which contains
# all of the & and = parts.
#
# Think of the query as the keywords to search for. However the query to the GSA can actually contain 
# several parts besides just keywords. If you are using metadata then the query can contain several 
# 'inmeta:' flags, for example. All of these combined with the keywords become one big long string, 
# each part separated by a space:
#
#   pizza inmeta:category=food inmeta:pieSize:12..18
#
# All of that is only the query (comes after ?q=). There are several additional options which the GSA requires, like
# 'collection' and 'client.' These are the options. The query and all of the options are combined
# into the final query string and sent to the GSA.
#
# A sample query string might look like:
#   ?q=pizza+inmeta:category=food+inmeta:pieSize:12..18&collection=default_collection&client=my_client&num=10
#
# (Note that spaces in the query are turned into + signs.) This full query string is then appended to the URL
# you provided in the config options when you initialized gasohol (see Google::new) and the request is made to
# the GSA. The results come back and are parsed and converted into a nicer format than XML.

require 'open-uri'
require 'hpricot'
require 'chronic'
require 'core_extensions'

class Gasohol
  
  include Exceptions::GasoholError
  
  attr_reader :config
  
  DEFAULT_OPTIONS = { :url => '',
                      :num => 10, 
                      :start => 0, 
                      :filter => 'p', 
                      :collection => 'default_collection', 
                      :client => 'default', 
                      :output => 'xml_no_dtd', 
                      :getfields => '*',
                      :sort => '',
                      :requiredfields => '',
                      :partialfields => '' }
  ALLOWED_PARAMS = DEFAULT_OPTIONS.keys
  DEFAULT_OUTPUT = {  :results => [], 
                      :featured => [], 
                      :google => { 
                        :query => '', 
                        :params => {}, 
                        :total_results => 0, 
                        :next => 0, 
                        :prev => 0, 
                        :google_query => '', 
                        :full_query_path => '',
                        :total_featured_results => 0 } 
                      }
  DEFAULT_RESULT = {  :num => 0, 
                      :mime => '', 
                      :level => 1, 
                      :url => '', 
                      :title => '', 
                      :abstract => '', 
                      :date => '', 
                      :meta => {}, 
                      :featured => false, 
                      :rating => 0 }
  DEFAULT_FEATURED_RESULT = { :url => '', :title => '', :featured => true }

  # To get gasohol ready, instantiate a new copy with Gasohol.new(config) where 'config' is a hash of options so that we know how/where
  # to access your GSA instance. This information is saved and used for every request after initializing your gasohol instance.
  # For Google's reference of what these options do, check out the Search Protocol Reference: http://code.google.com/apis/searchappliance/documentation/50/xml_reference.html
  #
  # == Required config options
  # * url => the URL to the search results page of your GSA. ie: http://127.0.0.1/search
  # * collection => the GSA can contain several collections, specify which one to use for this search
  # * client => the GSA can contain several clients, specify which one to use for this search
  #
  # == Optional config options
  # * filter => how to filter the results, defaults to 'p'
  # * output => the output format of the results, defaults to 'xml_no_dtd' (leave this setting alone for gasohol to work correctly)
  # * getfields => which meta tag values to return in the results, defaults to '*' (all meta tags)
  # * num => the default number of results to return, defaults to 25
  #
  # Example config hash:
  #   config => { :url => 'http://127.0.0.1',
  #               :collection => 'default_collection',
  #               :client => 'my_client',
  #               :num => 25 }
  #
  # So if you're using gasohol with Rails, for example, you would place the following in your search controller:
  #   @google = Gasohol.new(config)
  #
  # For a simple search now you go:
  #   @results = @google.search('pizza')
  #
  # What you'll get back in @results is a nicely formatted version of Google's response.
  
  def initialize(config=nil)
    # start with default values
    @config = DEFAULT_OPTIONS
    unless config.nil?
      @config.merge!(config)
    else
      raise MissingConfig, 'Missing config - you must pass some configuration options to tell gasohol how to access your GSA. See Gasohol::initialize for configuration options'
    end
    
    # make sure we have the minimum info we need to make a request
    if @config[:url].empty?
      raise MissingURL, 'Missing GSA URL - you must provide the URL to your GSA, ie: http://127.0.0.1/search'
    end
  end
  
  # Assembles the query and options into a big query string and sends over to your GSA.
  #
  #  @google = Google.new(config)
  #  @results = @google.search('pizza')
  
  def search(query,options={})    
    options = @config.merge(options)
 
    google_query = googlize_params_into_query(options,query)  # creates the q= part of the google search
    full_query_path = query_path(google_query,options)        # creates the full URL to the GSA
    
    begin
      # do the query and save the xml
      xml = Hpricot(open(full_query_path))
  
      # if all we really care about is the count of records from google, return just that number and get the heck outta here
      if options[:count_only] == 'true'
        return xml.search(:m).inner_html.to_i || 0
      end
      
      # the struct we're going to output
      output = Marshal.load(Marshal.dump(DEFAULT_OUTPUT))
      
      output[:google][:query] = query
      output[:google][:google_query] = google_query
      output[:google][:full_query_path] = full_query_path
      
      # total number of results
      output[:google][:total_results] = xml.search(:m).inner_html.to_i || 0
      
      # save params
      xml.search(:param).each do |param|
        output[:google][:params].merge!({param.attributes['name'].to_sym => param.attributes['value'].to_s})
      end
  
      # if there was at least one result, parse the xml
      if output[:google][:total_results] > 0
        output[:google][:total_featured_results] = xml.search(:gm).size
        # get featured results (called 'sponsored links' on the results page, displayed at the top)
        output[:featured] = xml.search(:gm).collect { |xml_featured| parse_featured_result(xml_featured) }
        # get regular results
        output[:results] = xml.search(:r).collect { |xml_result| parse_result(xml_result) }
        # TODO: Parse results into an object instead of hash
        # TODO: Add required will_paginate methods to automatically handle paging
      end
      
    rescue => e
      # error with results (the GSA barfed?)
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH GOOGLE RESPONSE: \n"+e.class.to_s+"\n"+e.message)
    end
    
    return output
  end


  private
  
  # a regular result
  def parse_result(xml)
    result = Marshal.load(Marshal.dump(DEFAULT_RESULT))
    result[:num] = xml.attributes['n'].to_i
    result[:mime] = xml.attributes['mime'] || 'text/html'
    result[:level] = xml.attributes['l'].to_i > 0 ? xml.attributes['l'].to_i : 1
    result[:url] = xml.at(:u) ? xml.at(:u).inner_html : ''
    result[:url_encoded] = xml.at(:ue) ? xml.at(:ue).inner_html : ''
    result[:title] = xml.at(:t) ? xml.at(:t).inner_html : ''
    result[:language] = xml.at(:lang) ? xml.at(:lang).inner_html : ''
    result[:abstract] = xml.at(:s) ? xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
    # result[:date] = xml.at(:fs) ? Chronic.parse(xml.at(:fs)[:value]) : ''
    result[:crawl_date] = xml.at(:crawldate) ? Chronic.parse(xml.at(:crawldate).inner_html) : ''
    if xml.at(:has)
      if xml.at(:has).at(:c)
        result[:cache] = {}
        result[:cache][:size] = xml.at(:has).at(:c).attributes['sz']
        result[:cache][:cid] = xml.at(:has).at(:c).attributes['cid']
        result[:cache][:encoding] = xml.at(:has).at(:c).attributes['enc']
      end
    end
    result[:meta][:media_types] = []
    xml.search(:mt).each do |meta|
      tag = { meta.attributes['n'].underscore.to_sym => meta.attributes['v'].to_s }
      # if this meta tag contgains 'date' in the name somewhere, parse it
      if tag.key.to_s.match(/date/i)
        result[:meta].merge!({ tag.key => Time.parse(tag.value) })
      else
        # if this is a media_type then append to an array, otherwise just set the key/value
        if tag.key == :media_type
          result[:meta][:media_types] << tag
        else
          result[:meta].merge!(tag)
        end
      end
    end
    result[:featured] = false
    return result
  end
  
  # a featured result
  def parse_featured_result(xml)
    result = Marshal.load(Marshal.dump(DEFAULT_FEATURED_RESULT))
    result[:url] = xml.at(:gl) ? xml.at(:gl).inner_html : ''
    result[:title] = xml.at(:gd) ? xml.at(:gd).inner_html : ''
    return result
  end
  
  # This method is only concerned with turning the query and all of the params into the Google query variable (q).
  # The options (collection, client, etc.) are defined in @config, which is used as a local 
  # variable 'options' in various places above.
  #
  # * 'parts' should contain a hash of everything that is _not_ the actual keyword query terms.
  # * 'query' is the keyword(s) query terms
  #
  # On most implementations that offer more than straight keyword matches you're going to want additional
  # parameters, like meta searches, to appear in the browser's URL so that the search can be uniquely identified
  # and ran again. These parameters will not be formatted correctly for Google. That's what this method will do. 
  # Extend the Gasohol class with your own and then override this method so you can build a query string specific 
  # to your implementation.
  #
  # == Example
  # You have an application that searches for pizzas. You want your URL to look something like:
  #
  #   http://pizzafinder.com/search?keyword=deep+dish&size=16&toppings=cheese
  #
  # Google doesn't know what to do with 'keyword,' 'size,' or 'toppings' so you need to turn those into something
  # it does understand. So you might extend this method to look like:
  #
  #   class PizzaFinder > Gasohol
  #     def googlize_params_into_query(parts,query)
  #       return "#{query} inmeta:panSize=#{parts[:size]} inmeta:toppings~#{parts[:toppings]"
  #     end
  #   end
  #
  # That string is appeneded to the GSA url and now it knows how to search:
  #
  #   http://gsa.pizzafinder.com/search?q=deep+dish+inmeta:panSize=16+inmeta:toppings~cheese&collection=etc,etc,etc
  #
  # And to get this whole process started:
  #
  #   finder = PizzaFinder.new(config)  # where 'config' is your hash of options to get the search engine ready (see above)
  #   finder.search(parts,query)        # where 'parts' is a hash of params in the URL not including the keywords
  #                                     # and 'query' is the actual keyword query
  def googlize_params_into_query(parts,query)
    return ''
  end
  
  # This method creates the combination of the url, query and options into one big URI
  def query_path(query,options)
    url = options.delete(:url)  # sets url to the value of options[:url] and then removes it from the hash
    output = url + '?q=' + CGI::escape(query)
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
  
end