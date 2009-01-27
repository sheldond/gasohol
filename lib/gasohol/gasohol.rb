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
# all of the & and = stuff.
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

require 'gasohol/exceptions'
require 'gasohol/result'

module Gasohol
  
  class Base
    
    include GasoholError
    attr_reader :config
  
    # default parameters that go to the GSA
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
    # the parameters that google cares about and will respond to
    ALLOWED_PARAMS = DEFAULT_OPTIONS.keys
    
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
  
  
    # This method does the actual searching. It accepts to parameters:
    #
    # * +query+ is the query string to google (q=)
    # * +options+ is a hash of parameters that could replace or augment DEFAULT_OPTIONS
    #
    # On most implementations that offer more than straight keyword searches you're going to want additional
    # parameters, like meta searches, to appear in the browser's URL so that the search can be uniquely identified
    # and run again. These parameters will not be formatted correctly for Google. So you'll want to extend Gasohol
    # write your own impementation of this method that at the end will call super and pass in a final query string
    # and hash of options.
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
    #     def search(parts,options={})
    #       super("#{query} inmeta:panSize=#{parts[:size]} inmeta:toppings~#{parts[:toppings]")
    #     end
    #   end
    #
    # And then use it like so (+params+ is the default Ruby on Rails hash or URL values):
    #
    #   the_finder = PizzaFinder.new(config)
    #   the_finder.search(params)
    #
    # That string is appeneded to the GSA url and now it knows how to search:
    #
    #   http://gsa.pizzafinder.com/search?q=deep+dish+inmeta:panSize=16+inmeta:toppings~cheese&collection=etc,etc,etc
  
    def search(query,options={})
      RAILS_DEFAULT_LOGGER.debug("\nGASOHOL: options=#{options.inspect}\n")
      RAILS_DEFAULT_LOGGER.debug("\nGASOHOL: query='#{query}'\n")
      all_options = @config.merge(options)    # merge options that were passed directly to this method
      RAILS_DEFAULT_LOGGER.debug("\nGASOHOL: all_options=#{all_options.inspect}\n")
      full_query_path = query_path(query,all_options)        # creates the full URL to the GSA
      RAILS_DEFAULT_LOGGER.debug("\nGASOHOL: full_query_path=#{full_query_path}\n\n")
    
      #begin
        # do the query and save the xml
        xml = Hpricot(open(full_query_path))
  
        # if all we really care about is the count of records from google, return just that number and get the heck outta here
        if all_options[:count_only] == true
          return xml.search(:m).inner_html.to_i || 0
        end
        
        # otherwise create a real resultset
        rs = ResultSet.new(query,full_query_path,xml,all_options[:num].to_i)
        
        # if there was at least one result, parse the xml
        if rs.total_results > 0
          rs.total_featured_results = xml.search(:gm).size
          rs.featured = xml.search(:gm).collect { |xml_featured| Featured.new(xml_featured) }           # get featured results (called 'sponsored links' on the results page, displayed at the top)
          rs.results = xml.search(:r).collect { |xml_result| Result.new(xml_result) }                   # get regular results
          # TODO: Add required will_paginate methods to automatically handle paging
        end
      
      #rescue => e
        # error with results (the GSA barfed?)
        # RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH GOOGLE RESPONSE: \n"+e.class.to_s+"\n"+e.message)
      #end
    
      return rs
    end


    private
    
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
end