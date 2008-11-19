require 'open-uri'
require 'hpricot'
require 'chronic'

class Google

  URL = GASOHOL_CONFIG['google']['url']
  DEFAULTS = {  :num => GASOHOL_CONFIG['google']['results'], 
                :start => 0, 
                :filter => 'p', 
                :collection => GASOHOL_CONFIG['google']['collection'], 
                :client => GASOHOL_CONFIG['google']['client'], 
                :output => 'xml_no_dtd', 
                :getfields => '*',
                :sort => 'date:A:S:d1' }
  ALLOWED_PARAMS = DEFAULTS.keys + [:inurl]
  ACTIVE_TO_GOOGLE_PARAMS = { :category => 'category', :sport => 'channel' }    # translate our URL parameters into ones that google understands
  DEFAULT_OUTPUT = {  :results => [], 
                      :featured => [], 
                      :google => { 
                        :query => '', 
                        :params => {}, 
                        :total_results => 0, 
                        :next => 0, 
                        :prev => 0, 
                        :google_query => '', 
                        :full_query_path => '' } 
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
  STATES = {  'al' => 'alabama',
              'ak' => 'alaska',
              'ar' => 'arkansas',
              'az' => 'arizona',
              'ca' => 'california',
              'co' => 'colorado',
              'ct' => 'connecticut',
              'dc' => 'district of columbia',
              'de' => 'delaware',
              'fl' => 'florida',
              'ga' => 'georgia',
              'hi' => 'hawaii',
              'id' => 'idaho',
              'ia' => 'iowa',
              'il' => 'illinois',
              'in' => 'indiana',
              'ks' => 'kansas',
              'ky' => 'kentucky',
              'la' => 'louisiana',
              'ma' => 'massachusetts',
              'md' => 'maryland',
              'me' => 'maine',
              'mi' => 'michigan',
              'mo' => 'missouri',
              'mn' => 'minnesota',
              'ms' => 'mississippi',
              'mt' => 'montana',
              'nc' => 'north carolina',
              'nd' => 'north dakota',
              'ne' => 'nebraska',
              'nh' => 'new hampshire',
              'nj' => 'new jersey',
              'nm' => 'new mexico',
              'ny' => 'new york',
              'nv' => 'nevada',
              'oh' => 'ohio',
              'ok' => 'oklahoma',
              'or' => 'oregon',
              'pa' => 'pennsylvania',
              'pr' => 'puerto rico',
              'ri' => 'rhode island',
              'sc' => 'south carolina',
              'sd' => 'south dakota',
              'tn' => 'tennessee',
              'tx' => 'texas',
              'ut' => 'utah',
              'va' => 'virginia',
              'vt' => 'vermont',
              'wa' => 'washington',
              'wi' => 'wisconsin',
              'wv' => 'west virginia',
              'wy' => 'wyoming' }
  
  def initialize(options={})
    @@options = DEFAULTS.merge(options)
  end
  
  def search(query,options={})    
    options = @@options.merge(options)
    
    # the struct we're gonna output
    output = DEFAULT_OUTPUT

    # the keyword string that was searched for
    output[:google][:query] = query
    output[:google][:google_query] = googlize_options_into_query(options,output[:google][:query])   # the actual query string that we actually send to google (will probably include meta values)
    output[:google][:full_query_path] = query_path(output[:google][:google_query],options)
  
    begin
      # do the query and save the xml
      xml = Hpricot(open(output[:google][:full_query_path]))
    
      # set params
      xml.search(:param).each do |param|
        output[:google][:params].merge!({param.attributes['name'].to_sym => param.attributes['value'].to_s})
      end
  
      # total number of results
      output[:google][:total_results] = xml.search(:m).inner_html.to_i || 0
  
      # if there was at least one result, parse the xml
      if output[:google][:total_results] > 0
        #
        # get featured results (called 'sponsored links' on the results page, displayed at the top)
        #
        output[:featured] = xml.search(:gm).collect do |xml_result|
          result = Marshal.load(Marshal.dump(DEFAULT_FEATURED_RESULT))
          result[:url] = xml.at(:gl) ? xml.at(:gl).inner_html : ''
          result[:title] = xml.at(:gd) ? xml.at(:gd).inner_html : ''
          result
        end
        #
        # get regular results
        #
        output[:results] = xml.search(:r).collect do |xml|
          result = Marshal.load(Marshal.dump(DEFAULT_RESULT))
          result[:num] = xml.attributes['n'].to_i
          result[:mime] = xml.attributes['mime'] || 'text/html'
          result[:level] = xml.attributes['l'].to_i > 0 ? xml.attributes['l'].to_i : 1
          result[:url] = xml.at(:u) ? xml.at(:u).inner_html : ''
          result[:title] = xml.at(:t) ? xml.at(:t).inner_html : ''
          result[:abstract] = xml.at(:s) ? xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
          result[:date] = xml.at(:fs) ? Chronic.parse(xml.at(:fs)[:value]) : ''
          xml.search(:mt).each do |meta|
            if meta.attributes['n'].match(/date/i)
              result[:meta].merge!({ meta.attributes['n'].underscore.to_sym => Chronic.parse(meta.attributes['v']) })
            else
              result[:meta].merge!({ meta.attributes['n'].underscore.to_sym => meta.attributes['v'].to_s })
            end
          end
          result[:featured] = false
          result
        end
      end
      
    rescue => e
      # error with results
      RAILS_DEFAULT_LOGGER.error("\n\nERROR WITH GOOGLE RESPONSE: \n"+e.class.to_s+"\n"+e.message)
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

  def googlize_options_into_query(options,query)
    
    # are we searching just a single url?
    if options[:inurl] and !options[:inurl].blank?
      query += ' inurl:' + options[:inurl]
    end
  
    # get the easy query params and convert to meta values google knows about
    ACTIVE_TO_GOOGLE_PARAMS.each do |key,value|
      if options[key] and !options[key].blank? and options[key] != 'Any'
        query += " inmeta:#{value}=#{options[key]}"
      end
    end
    
    # turn the 'custom' field into a subMediaType, which is really  mediaType\subMediaType
    if options[:type] and !options[:type].blank? and options[:type] != 'Any'
      query += " inmeta:mediaType=#{options[:type]}"
      # if options[:custom] and !options[:custom].blank?
      #  query += "\\#{options[:custom]}"
      # end
    end

    # do the start/end date. If there isn't one, set to today by default
    if options[:start_date].nil? || options[:start_date].blank?
      options[:start_date] = Time.now.to_s(:standard)
    end
    
    #if options[:start_date] and !options[:start_date].blank?
      query += ' inmeta:startDate:daterange:' + Chronic.parse(options[:start_date]).strftime('%Y-%m-%d') + '..'
      if options[:end_date] and !options[:end_date].blank?
        query += Chronic.parse(options[:end_date]).strftime('%Y-%m-%d')
      end
    #end
  
    # do the location
    
    # if there's no specified radius, set to the default in config/gasohol.yml
    if options[:latitude] && options[:longitude]
      if options[:radius].nil? || options[:radius].blank?
        options[:radius] = GASOHOL_CONFIG['google']['default_radius'].to_f
      end
    
      options[:radius] = options[:radius].to_f
    
      # based on latitude/longitude
      latitude1 = ((options[:latitude] - (options[:radius] / 69.1)) * 10000).round.to_f / 10000
      latitude2 = ((options[:latitude] + (options[:radius] / 69.1 )) * 10000).round.to_f / 10000
      longitude1 = ((options[:longitude] - (options[:radius] / (69.1 * Math.cos(options[:latitude]/57.3)))) * 10000).round.to_f / 10000
      longitude2 = ((options[:longitude] + (options[:radius] / (69.1 * Math.cos(options[:latitude]/57.3)))) * 10000).round.to_f / 10000
    
      query += " inmeta:latitude:#{latitude1}..#{latitude2} inmeta:longitude:#{longitude1}..#{longitude2}"
    end
    
=begin 
    # location based on city,state or zip
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

      elsif options[:location].to_i > 0    
        if options[:radius].downcase != 'any'                     # zip code, and there's a radius          
          output[:zip] = Zip.find_within_radius(options[:location],options[:radius]).collect do |zip|
            zip[:zip]
          end
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
        if key == :zip and !value.blank?
          # zips have special formatting -- looks like: inmeta:zip~12345 OR inmeta:zip~67890
          value.each_with_index do |val,index|
            query += " inmeta:zip=#{val}"
            unless index == value.length-1
              query += " OR"
            end
          end
        else
          unless value.blank?
            query += " inmeta:#{key.to_s}~#{value}"
          end
        end
      end
    
    end
=end

    return query
    
  end
  
end