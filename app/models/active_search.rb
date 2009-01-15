# Extends the default Gasohol class with logic that's specific to Active's implementation
class ActiveSearch < Gasohol
  
  ACTIVE_TO_GOOGLE_PARAMS = { :category => 'category', :sport => 'channel' }    # translate our URL parameters into ones that google understands
  
  # In order to format a query for Google that uses Active's specific data structure, we extend this method
  # with logic specific to us.
  #
  # 'parts' is just the default Rails params hash (minus Rails-specific params like :controller or :action)
  # 'query' looks like '?q=keywords' when we start. We append on to this with the parts of 'parts' that we care about.
  def googlize_params_into_query(parts,query)
    
    # exclude shooting results
    query += ' -inmeta:channel=Shooting'
    parts = parse_location(parts)
    
    # are we searching just a single url?
    if parts[:inurl] and !parts[:inurl].blank?
      query += ' inurl:' + parts[:inurl]
    end

    # get the easy query params and convert to meta values google knows about
    ACTIVE_TO_GOOGLE_PARAMS.each do |key,value|
      if parts[key] and !parts[key].blank? and parts[key] != 'Any'
        query += " inmeta:#{value}=#{parts[key]}"
      end
    end

    # 'type' is the active.com 'mediaType', 'custom' is 'subMediaType'
    # when mediaType and subMediaType are input into GSA it's in the form mediaType\subMediaType
    # if 'custom' exists then only do a "contains" search with ~ which will look to see if the mediaType
    # meta tag contains subMediaType anywhere within it.
    # they mediaType field contains the subMediaType in it anywhere
    if parts[:type] and !parts[:type].blank? and parts[:type] != 'Any'
      query += " inmeta:mediaType~#{parts[:type]}"
      if parts[:custom] and !parts[:custom].blank?
        query += " inmeta:mediaType~#{parts[:custom]}"
      end
    end

    # do the start/end date - create a valid dateRange for GSA
    if parts[:start_date] and !parts[:start_date].blank?
      query += ' inmeta:startDate:daterange:' + Chronic.parse(parts[:start_date]).strftime('%Y-%m-%d') + '..'
      if parts[:end_date] and !parts[:end_date].blank?
        query += Chronic.parse(parts[:end_date]).strftime('%Y-%m-%d')
      end
    end
    
    if parts[:location]
      begin
        if 
          case location.type
          when :everywhere
            nil
          when :only_state
            parts.merge!({ :state => location.state })
          else
            parts.merge!({ :latitude => location.latitude, :longitude => location.longitude, :radius => location.radius })
          end
        end
      rescue  # if there was an error with the location, just search everywhere
        RAILS_DEFAULT_LOGGER.info("\n\nActiveSearch.googlize_params_into_query: Location in URL is bogus: '#{parts[:location]}'\n\n")
      end
    end

    # do the location
    # if there's no specified radius, set to the default in config/gasohol.yml
    if parts[:latitude] && parts[:longitude]
      if parts[:radius].nil? || parts[:radius].blank?
        parts[:radius] = GASOHOL_CONFIG[:google][:default_radius]
      end

      # make sure the radius is floating point number
      parts[:radius] = parts[:radius].to_f

      # do a little math to figure out the max/min latitude/longitude around the current location
      # and create a range for the GSA to search in
      latitude1 = ((parts[:latitude] - (parts[:radius] / 69.1)) * 10000).round.to_f / 10000
      latitude2 = ((parts[:latitude] + (parts[:radius] / 69.1 )) * 10000).round.to_f / 10000
      longitude1 = ((parts[:longitude] - (parts[:radius] / (69.1 * Math.cos(parts[:latitude]/57.3)))) * 10000).round.to_f / 10000
      longitude2 = ((parts[:longitude] + (parts[:radius] / (69.1 * Math.cos(parts[:latitude]/57.3)))) * 10000).round.to_f / 10000

      query += " inmeta:latitude:#{latitude1}..#{latitude2} inmeta:longitude:#{longitude1}..#{longitude2}"
    elsif parts[:state]
      # otherwise there was a state
      query += " inmeta:state~#{parts[:state]}"
    end

    return query
  end
  
  
  def parse_location(p)
    location = SearchController::get_location_from_params(p)
    # add in the user's location
    if p[:location]
      case location.type
      when :everywhere
        nil
      when :only_state
        p.merge!({ :state => location.state })
      else
        p.merge!({ :latitude => location.latitude, :longitude => location.longitude, :radius => location.radius })
      end
    end
    return p
  end
  
end