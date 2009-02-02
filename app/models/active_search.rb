# Extends the default Gasohol class with logic that's specific to Active's implementation.
# All the messyness of how we search for different types of pages is all encapsulated here.
# ie: searching in community actually adds an +inurl:community.active.com+ rather than a standard
# +inmeta:category=foo+ since there are no community pages in asset service
#
# +parts+ is just the default Rails params hash
# +options+ is a hash that contains values to replace or augment Gasohol::DEFAULT_OPTIONS as well as any
#   directives that should trigger some special behavior (like :skip_deep_keyword_search)

require 'location'
require 'override'
require 'gasohol/gasohol'
require 'active_result'

class ActiveSearch < Gasohol::Search
		
	def search(parts,options={})
	  
	  RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: search: passed parts='#{parts.inspect}'\n")
	  RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: search: passed options='#{options.inspect}'\n")
		
		# Sometimes we want to override the user's filter settings if they did a simple keyword search
		# but we think we can get better results by injecting some extra pizzaz into the query to the GSA
		if simple_search?(parts)
			if override = Override.search(parts[:q])
			  RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: search: using override='#{override.to_options.inspect}'\n")
				parts.merge!(override.to_options)
			end
		end
				

		# TODO: add a test for sport in keywords box as well
		#test_keywords_for_sport(params[:q])


    # assume that any options passed in at this point will be output at the end
    output_options = options.dup

    # did they type location-type things into the keywords box?
    unless options[:skip_deep_keyword_search]
      modified_keyword, modified_location = deep_keyword_search(parts[:q])
      unless modified_keyword.nil? && modified_location.nil?
        # override the passed keyword and location values with these
        parts[:q] = modified_keyword
        parts[:location] = modified_location
  	  end
  	  output_options.delete :skip_deep_keyword_search   # we don't want this one passed on to gasohol
	  end
	  
	  query = "#{parts[:q]}"
		
		# sport (asset service knows these as 'channels')
		if parts[:sport] && !parts[:sport].blank? && parts[:sport].downcase != 'any'
			query += " inmeta:channel=#{parts[:sport]}"
		end

    # location (this can mean a lot of different things so we do some work in each mode below depending on what that asset type 
    # needs as location data (ie. some need state name, some need state abbreviation)
    if parts[:location]
  		location = Location.new!(parts[:location])
    end

		# mode (asset service knows these as 'categories')
		# This part is ugly. Since different assets are stored in different ways we need different query strings to access them
		# all. For example there are no community assets so the GSA only knows about community stuff that it crawls organicly. So
		# rather than query for meta data we can only limit by url  (inurl:community.active.com)
		if parts[:mode] && !parts[:mode].blank? && parts[:mode].downcase != 'any'
			case parts[:mode]
			  
			# activity and event search
			when 'activities'
				query += " inmeta:category=activities"
				query += ' -inmeta:channel=Shooting'
				if location
  				case location.type
      		when :only_state
        		query += " inmeta:state~#{location.state[:name]}"   # activities are in asset service by state name
      		when :city_state
      			query += figure_latitude_longitude(location.latitude, location.longitude, parts[:radius] || location.radius)  # radius in URL wins over radius in location object
      		end
    		end
    		
    	# race results search
			when 'results'
				query += " inurl:results.active.com"
				
			# training search
			when 'training'
				query += " inmeta:category=products"
				if parts[:difficulty] && parts[:difficulty].downcase != 'any'
					query += " inmeta:participationCriteria=#{parts[:difficulty]}"
				end
				
			# article search
			when 'articles'
				query += " inmeta:category=articles"
				
			# community search
			when 'community'
				query += " inurl:community.active.com"
				
			# clubs & orgs search
			when 'orgs'
				query += " inmeta:category=organizations"
				if location
  				case location.type
      		when :only_state
      			query += " inmeta:state~#{location.state[:abbreviation]}"   # orgs are in asset service by state abbreviation
      		when :city_state
      			query += figure_latitude_longitude(location.latitude, location.longitude, parts[:radius] || location.radius)  # radius in URL wins over radius in location object
      		end
    		end
    		
    	# facility search
			when 'facilities'
				query += " inmeta:category=facilities"
				if location
  				case location.type
      		when :only_state
      			query += " inmeta:state~#{location.state[:abbreviation]}"   # facilities are in asset service by state abbreviation
      		when :city_state
      			query += figure_latitude_longitude(location.latitude, location.longitude, parts[:radius] || location.radius)  # radius in URL wins over radius in location object
      		end
    		end
			end
		end
		
		
		# the following parts apply to any asset type so they don't need to go in the case statement above
		

		# +type+ is the active.com +mediaType+, +custom+ is +subMediaType+
		# when mediaType and subMediaType are input into GSA it's in the form mediaType\subMediaType
		# if 'custom' exists then only do a "contains" search with ~ which will look to see if the mediaType
		# meta tag contains subMediaType anywhere within it.
		if parts[:type] and !parts[:type].blank? and parts[:type] != 'Any'
			query += " inmeta:mediaType~#{parts[:type]}"
			if parts[:custom] and !parts[:custom].blank?
				query += " inmeta:mediaType~#{parts[:custom]}"
			end
		end

		# do the start/end date - create a valid GSA dateRange
		if parts[:start_date] and !parts[:start_date].blank?
			query += ' inmeta:startDate:daterange:' + Chronic.parse(parts[:start_date]).strftime('%Y-%m-%d') + '..'
			if parts[:end_date] and !parts[:end_date].blank?
				query += Chronic.parse(parts[:end_date]).strftime('%Y-%m-%d')
			end
		end
		
		# Figure out any GSA options that might have been included in the +parts+ hash (instead of explicitly set in the +options+ hash)
		
		output_options.merge!({:num => parts[:num].to_i}) if parts[:num] && !options[:num]            # if num was set don't override that here
		if parts[:page]  # convert +page+ to +start+ (which GSA understands)
		  start_num = parts[:page].to_i * (output_options[:num].to_i || @config[:num]) - (output_options[:num].to_i || @config[:num])
		  output_options.merge!({:start => start_num}) 
	  end
		output_options.merge!({:sort => 'date:A:S:d1'}) if !options[:sort] && parts[:sort] && parts[:sort] == 'date'      # only merge in the date if it didn't come in as part of the options
		output_options.merge!({:count_only => true}) if parts[:count_only] && (parts[:count_only] == true || parts[:count_only] == 'true')
		output_options.merge!({:partialfields => parts[:partialfields]}) if parts[:partialfields]

    RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: search: computed query='#{query}'\n")
		RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: search: computed options='#{output_options.inspect}'\n")

		super(query,output_options)
	end
	
	
	private
	
	# override default Gasohol::Result::parse_result method so we can pass our own Result object with some extended methods
	def parse_result(xml)
	  ActiveResult.new(xml)
  end
  
	
	# do a little math to figure out the max/min latitude/longitude around the current location and create a range for the GSA to search in
	def figure_latitude_longitude(lat,long,radius)
		# make sure the radius is floating point number
		radius = radius.to_f
		latitude1 = ((lat - (radius / 69.1)) * 10000).round.to_f / 10000
		latitude2 = ((lat + (radius / 69.1 )) * 10000).round.to_f / 10000
		longitude1 = ((long - (radius / (69.1 * Math.cos(lat/57.3)))) * 10000).round.to_f / 10000
		longitude2 = ((long + (radius / (69.1 * Math.cos(lat/57.3)))) * 10000).round.to_f / 10000

		return " inmeta:latitude:#{latitude1}..#{latitude2} inmeta:longitude:#{longitude1}..#{longitude2}"
	end
	
	
	# Determines whether this is a search that uses only keywords
	def simple_search?(values)
		(values[:mode] && values[:mode].downcase == 'activities') && (values[:sport].nil? || values[:sport].downcase == 'any') && (values[:type].nil? || values[:type].downcase == 'any') && (values[:custom].nil? || values[:custom].downcase == 'any')
	end
	
	
	# Search keywords for special trigger phrases like a location or a sport
	def deep_keyword_search(text)
	  
	  RAILS_DEFAULT_LOGGER.debug("\nActiveSearch: test_keywords_for_location: text='#{text}'\n")
		
		# Try the whole keyword block first
		keywords = ''
		location = text
		begin
			found_location = Location.new(location)
		rescue
		end
		
		# if the whole keyword didn't match, how about various parts of it?
		unless found_location
			if text.split(' near ').length > 1
				keywords, location = text.split(' near ')			# "running near atlanta, ga"
				begin
					found_location = Location.new(location)
				rescue
				end
			elsif text.split(' in ').length > 1
				keywords, location = text.split(' in ')				# "running in california"
				begin
					found_location = Location.new(location)
				rescue
				end
			elsif text.split(' ').length > 1								# "running atlanta"	 or	 "running san diego"	but not	 "running san diego, ca" (ca is the valid location, "running san diego" becomes the keywords)
				parts = text.split(' ').reverse								# Starting from the end of multiple keywords, check if the last word is a valid location, if not then add the second to last word to the string and check that, etc.
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
		  RAILS_DEFAULT_LOGGER.debug("SearchController.test_keywords_for_location: Location found in keywords '#{text}'")
		  return [keywords,found_location.form_value]
		else
		  return [nil,nil]
	  end
	end
	
	
	# test if the keywords contained a sport
	def test_keywords_for_sport(text)
	  # matched sport = sports.find { |sport| text.match(/ #{sport} /) }

	end
  
end