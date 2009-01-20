# Extends the default Gasohol class with logic that's specific to Active's implementation.
# All the messyness of how we search for different types of pages is all encapsulated here.
# ie: searching in community actually adds an +inurl:community.active.com+ rather than a standard
# +inmeta:category=foo+ since there are no community pages in asset service
#
# +parts+ is just the default Rails params hash (minus Rails-specific params like :controller or :action)
# +query+ looks like '?q=keywords' when we start. We append on to this with the data we care about, interpreted from +parts+
require 'location'

class ActiveSearch < Gasohol
    
  def googlize_params_into_query(parts)
    
    query = "#{parts[:q]}"
    
=begin

    # Sometimes we want to override the user's filter settings if they did a simple keyword search
    # but we think we can get better results by injecting some extra pizzaz into the query to the GSA
    if simple_search?(@options)
      if @override = Override.find_by_keywords(@query)
        @options.merge!(@override.to_options)
      end
    end

    # did they type location-type things into the keywords box?
    test_keywords_for_location!(params[:q])


=end
    
    # channel
    if parts[:sport] && !parts[:sport].blank? && parts[:sport].downcase != 'any'
      query += " inmeta:channel=#{parts[:sport]}"
    end

    # category
    if parts[:mode] && !parts[:mode].blank? && parts[:mode].downcase != 'any'
      case parts[:mode]
      when 'activities'
        query += " inmeta:category=activities"
        query += ' -inmeta:channel=Shooting'
      when 'results'
        query += " inurl:results.active.com"
      when 'training'
        query += " inmeta:category=products"
        if parts[:difficulty] && parts[:difficulty].downcase != 'any'
          query += " inmeta:participationCriteria=#{parts[:difficulty]}"
        end
      when 'articles'
        query += " inmeta:category=articles"
      when 'community'
        query += " inurl:community.active.com"
      when 'orgs'
        query += " inmeta:category=organizations"
      when 'facilities'
        query += " inmeta:category=facilities"
      end
    end

    # +type+ is the active.com +mediaType+, +custom+ is +subMediaType+
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
      #begin
        location = Location.new(parts[:location])
        case location.type
        when :everywhere
          nil
        when :only_state
          parts.merge!({ :state => location.state })
        else
          parts.merge!({ :latitude => location.latitude, :longitude => location.longitude, :radius => location.radius })
        end
      #rescue  # if there was an error with the location, just search everywhere
      #  RAILS_DEFAULT_LOGGER.error("\n\nActiveSearch.googlize_params_into_query: Location in URL is bogus: '#{parts[:location]}'\n\n")
      #end
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
    
    options = {}
    options.merge!({:num => parts[:num]}) if parts[:num]
    options.merge!({:sort => 'date:A:S:d1'}) if parts[:sort] == 'date'

    RAILS_DEFAULT_LOGGER.debug("\n\nActiveSearch:options: '#{options.inspect}'\n\n")

    return [query,options]
  end
  
  
  private
  # Determines whether this is search that uses only keywords
  def simple_search?(options)
    (options[:category] && options[:category].downcase == 'activities') && (options[:sport].nil? || options[:sport].downcase == 'any') && (options[:type].nil? || options[:type].downcase == 'any') && (options[:custom].nil? || options[:custom].downcase == 'any')
  end
  
  
  # This gets a bang (!) because it will change params based on whether or not a location was found in the passed text string 
  def test_keywords_for_location!(text)
    
    # Try the whole keyword block first
    keywords = ''
    location = params[:q]
    begin
      found_location = Location.new(params[:q])
    rescue
    end
    
    # if the whole keyword didn't match, how about various parts of it?
    unless found_location
      if params[:q].split(' near ').length > 1
        keywords, location = params[:q].split(' near ')     # "running near atlanta, ga"
        begin
          found_location = Location.new(location)
        rescue
        end
      elsif params[:q].split(' in ').length > 1
        keywords, location = params[:q].split(' in ')       # "running in california"
        begin
          found_location = Location.new(location)
        rescue
        end
      elsif params[:q].split(' ').length > 1                # "running atlanta"  or  "running san diego"  but not  "running san diego, ca" (ca is the valid location, "running san diego" becomes the keywords)
        parts = params[:q].split(' ').reverse               # Starting from the end of multiple keywords, check if the last word is a valid location, if not then add the second to last word to the string and check that, etc.
        from = 0
        to = parts.length
        until from == to
          location = parts[0..from].reverse.join(' ')
          keywords = parts[from+1..to].reverse.join(' ')
          begin
            found_location = Location.new(location)
          rescue
          end
          break if found_location
          from += 1
        end
      end
    end
      
    # if it was found, reset the params
    if found_location
      params[:q] = keywords
      params[:location] = found_location.form_value
      logger.debug("SearchController.test_keywords_for_location: Location found in keywords '#{params[:q]}'")
    end
  end
  
end