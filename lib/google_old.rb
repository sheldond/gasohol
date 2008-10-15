class Google

  DEFAULTS = {:num => 10, :start => 0, :filter => 'p', :collection => 'active_collection', :client => 'active_frontend', :output => 'xml_no_dtd', :getfields => '*'}
  ALLOWED_PARAMS = DEFAULTS.keys + [:sort]
  DATE_SORT_HASH = { :sort => 'date:B:S:d1' }
  STATES = { 'ca' => 'california', 'ny' => 'new york', 'tx' => 'texas'}
  ACTIVE_TO_GOOGLE_PARAMS = { :cateogry => 'category', :sport => 'channel', :type => 'mediatype' }    # translate our URL parameters into ones that google understands
  
  attr_accessor :query, :params, :total_results, :results, :featured, :next, :prev, :google_query, :full_query_path
  
  def initialize(url,options={})
    @@options = DEFAULTS.merge(options)
    @@search_url = url
  end
  
  def search(query,options={})
    options = @@options.merge(options)
    # if this is only an activity search, sort by the date of the event
    if activity_only_search(options)
      options.merge! DATE_SORT_HASH
    end
    # the keyword string that was searched for
    @query = query
    @google_query = googlize_options_into_query(options,@query)   # the actual query string that we actually send to google (will probably include meta values)
    @full_query_path = query_path(@google_query,options)
    xml = Hpricot(open(@full_query_path))
    @results = []
    @featured = []
    @params = {}
    # set params
    @params = xml.search(:param).each do |param|
      @params.merge!({param.attributes['name'].to_sym => param.attributes['value'].to_s})
    end
    # total number of results
    @total_results = xml.search(:m).inner_html.to_i || 0
    
    if @total_results > 0
      # get sponsored links
      xml.search(:gm).each do |xml_result|
        @featured << Feature.new(xml_result)
      end
      # get regular results
      xml.search(:r).each do |xml_result|
        @results << Result.new(xml_result)
      end
    end
      
    return self
  end
  
  private
  def query_path(query,options)
    output = @@search_url + '?q=' + CGI::escape(query)
    options.each do |option|
      if ALLOWED_PARAMS.include? option.first
        output += "&#{CGI::escape(option.first.to_s)}=#{CGI::escape(option.last.to_s)}"
      end
    end
    output
  end
  
  def activity_only_search(options)
    options.has_key? :activities_only
  end
  
  def googlize_options_into_query(options,query)
    
    # get the easy query params and convert to meta values google knows about
    ACTIVE_TO_GOOGLE_PARAMS.each do |key,value|
      if options[key] and !options[key].blank? and options[key] != 'any'
        query += " inmeta:#{value}=#{options[key]}"
      end
    end

    # do the start/end date
    if options[:start_date] and !options[:start_date].blank?
      query += ' inmeta:startDate:daterange:' + Chronic.parse(options[:start_date]).strftime('%Y-%m-%d') + '..'
      if options[:end_date] and !options[:end_date].blank?
        query += Chronic.parse(options[:end_date]).strftime('%Y-%m-%d')
      end
    end
    
    # do the location
    if options[:location] and !options[:location].blank?
      output = { :city => '', :state => '', :zip => ''}
      # take the location and split on commas, removing extra whitespace and put into a new array
      location_parts = options[:location].split(',').collect { |part| part.strip }
      # is there more than one part to the location?
      if location_parts.length > 1
        
        output[:city] = location_parts.first
        if STATES.has_key? location_parts.last.downcase
          output[:state] = STATES[location_parts.last.downcase]   # user entered abbreviation, replace with full state name
        else
          output[:state] = location_parts.last                    # already had full state name
        end

      elsif STATES.has_value? options[:location].downcase
        output[:state] = options[:location]                       # user entered full state only
      elsif STATES.has_key? options[:location].downcase
        output[:state] = STATES[options[:location].downcase]      # user entered state abbreviation
      else
        output[:city] = options[:location]                        # user entered something we don't recognize, assume it's a city
      end
      
      # put city/state/zip into query string
      output.each do |key,value|
        unless value.blank?
          query += " inmeta:#{key.to_s}~#{CGI::escape(value)}"
        end
      end
      
    end

    return query
  end
  
end
