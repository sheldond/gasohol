# Extends the default Gasohol class with logic that's specific to Active's implementation
class Active < Google
  
  ACTIVE_TO_GOOGLE_PARAMS = { :category => 'category', :sport => 'channel' }    # translate our URL parameters into ones that google understands
  
  def googlize_options_into_query(parts,query)

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
    # if 'custom' exists then only do a "contains" search with ~ we'll do a ~ search to see if 
    # they mediaType field contains the subMediaType in it anywhere
    if parts[:type] and !parts[:type].blank? and parts[:type] != 'Any'
      if parts[:custom] and !parts[:custom].blank?
        query += " inmeta:mediaType~#{parts[:custom]}"
      else
        query += " inmeta:mediaType=#{parts[:type]}"
      end
    end

    # do the start/end date - create a valid dateRange for GSA
    if parts[:start_date] and !parts[:start_date].blank?
      query += ' inmeta:startDate:daterange:' + Chronic.parse(parts[:start_date]).strftime('%Y-%m-%d') + '..'
      if parts[:end_date] and !parts[:end_date].blank?
        query += Chronic.parse(parts[:end_date]).strftime('%Y-%m-%d')
      end
    end

    # do the location
    # if there's no specified radius, set to the default in config/gasohol.yml
    if parts[:latitude] && parts[:longitude]
      if parts[:radius].nil? || parts[:radius].blank?
        parts[:radius] = GASOHOL_CONFIG['google']['default_radius'].to_f
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
    end

=begin 
    # location based on city,state or zip
    if parts[:location] and !parts[:location].blank?
      output = { :city => '', :state => '', :zip => ''}
      # take the location and split on commas, removing extra whitespace and put into a new array
      location_parts = parts[:location].split(',').collect { |part| part.strip }
      # is there more than one part to the location?
      if location_parts.length > 1

        parts[:city] = location_parts.first
        if STATES.has_key? location_parts.last.downcase
          parts[:state] = STATES[location_parts.last.downcase]   # user entered abbreviation, replace with full state name
        else
          parts[:state] = location_parts.last                    # already had full state name
        end

      elsif parts[:location].to_i > 0    
        if parts[:radius].downcase != 'any'                     # zip code, and there's a radius          
          output[:zip] = Zip.find_within_radius(parts[:location],parts[:radius]).collect do |zip|
            zip[:zip]
          end
        end
      elsif STATES.has_value? parts[:location].downcase
        output[:state] = parts[:location]                       # user entered full state only
      elsif STATES.has_key? parts[:location].downcase
        output[:state] = STATES[parts[:location].downcase]      # user entered state abbreviation
      else
        output[:city] = parts[:location]                        # user entered something we don't recognize, assume it's a city
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