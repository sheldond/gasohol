# Any time we reference 'location' it should be an instance of this class.
# 'location' refers to an area to search. That can be within the radius of a zip code, an entire state
# or anywhere (the entire country)

class Location
  
  include Exceptions::LocationError
  
  DEFAULT_LOCATION = 'everywhere'
  DEFAULT_OPTIONS = { :radius => GASOHOL_CONFIG[:google][:default_radius] }
  ANYWHERE_PHRASES = ['anywhere','everywhere','any','us','usa','united states']
  
  attr_reader :zip, :city, :state, :latitude, :longitude, :radius, :everywhere
  
  def initialize(obj,options={})
    options = DEFAULT_OPTIONS.merge!(options)
    @zip, @city, @latitude, @longitude, @radius = nil
    @state = {}
    @everywhere = false
    
    parse(obj,options)
  end
  
  
  # Using Location.new!(text) ignores any errors and will create a location for 'everywhere' if there is any error
  def self.new!(obj,options={})
    begin
      self.new(obj,options)
    rescue 
      self.new(DEFAULT_LOCATION)
    end
  end
  
  
  # Alias 'new' as 'from_cookie' if we are creating a new Location from a cookie 
  # (looks more syntactically correct when called in the context of creating a Location object from a cookie)
  def self.from_cookie(obj,options={})
    new(obj,options)
  end
  
  def empty?
    return (@zip.nil? && @city.nil? && @state.empty? && !@everywhere) ? true : false
  end
  
  # Return a Hash version of this object
  def to_h
    { :zip => @zip,
      :city => @city,
      :state => @state,
      :latitude => @latitude,
      :longitude => @longitude,
      :radius => @radius,
      :everywhere => @everywhere }
  end
  
  # Return a version of this object ready to go into a cookie
  def to_cookie
    self.to_h.to_json
  end
  
  # Figures out if this is only a state-search
  def only_state?
    return (!@state.empty? && @city.nil? && @zip.nil?) ? true : false
  end
  
  # Does this location represent everywhere?
  def everywhere?
    return self.type == :everywhere ? true : false
  end
  
  def only_state?
    return self.type == :only_state ? true : false
  end
  
  def city_state?
    return self.type == :city_state ? true : false
  end
  
  # Tells us what kind of Location this is
  def type
    if @everywhere
      return :everywhere
    elsif !@state.empty? && @zip.nil? && @city.nil?
      return :only_state
    else
      return :city_state
    end
  end
  
  # Outputs the proper string for the location input field in a search form
  def form_value
    case type
    when :everywhere
      return 'everywhere'
    when :only_state
      return @state[:name].titlecase
    else
      return "#{@city.titlecase}, #{@state[:name].titlecase}"
    end
  end
  
  # outputs the correct modifier and place name for display
  def display_value
    output = "<strong>#{form_value}</strong>"
    case type
    when :everywhere
      return output
    when :only_state
      return "in #{output}"
    else
      return "near #{output}"
    end
  end
  
  private
  
  # Does the work of actually parsing the text passed in and figuring out what this is supposed to be
  def parse(obj,options)
    
    # this is already a valid location hash
    if (ActiveSupport::JSON.decode(obj)).is_a?(Hash)
      loc = ActiveSupport::JSON.decode(obj)
      @zip = loc['city']
      @city = loc['city']
      @state = { :name => loc['state']['name'], :abbreviation => loc['state']['abbreviation'] }
      @latitude = loc['latitude'].to_f
      @longitude = loc['longitude'].to_f
      @radius = loc['radius'].to_f
      @everywhere = loc['everywhere']
      return
    end
    
    # if this is text, strip off any whitespace
    if obj.respond_to?('strip!')
      obj.strip!
    end
    
    # special 'anywhere' text
    if ANYWHERE_PHRASES.include?(obj.downcase)
      @everywhere = true
      return
    end
    
    # zip code
    if obj.to_i > 0
      if zip = Zip.find_by_zip(obj)
        state =  State.find_by_abbreviation(zip.state.downcase)
        @zip = zip.zip
        @city = zip.city
        @state = { :name => state.name.titlecase, :abbreviation => state.abbreviation }
        @latitude = zip.latitude.to_f
        @longitude = zip.longitude.to_f
        @radius = options[:radius].to_f
        return
      else
        raise InvalidZip, "Zip code '#{obj}' was not found."
      end
    end
    
    # city or state or city,state
    if obj.split(',').length > 1   # in the form of city,state
      city,state = obj.split(',').each { |part| part.strip! }
      if state = State.find_by_name_or_abbreviation(state) 
        if zips = Zip.find_all_by_city_and_state(city.titlecase, state.abbreviation.upcase)
          center = find_center_point_of(zips)
          # @zip = zips.collect { |zip| zip.zip }   # if it's a city/state then @zip contains an array of zips
          state = State.find_by_abbreviation(zips[0].state.downcase)
          @city = zips[0].city
          @state = { :name => state.name.titlecase, :abbreviation => state.abbreviation }
          @latitude = center[:latitude].to_f
          @longitude = center[:longitude].to_f
          @radius = options[:radius].to_f
          return
        else
          raise InvalidCityState, "No location was found matching '#{obj}'"
        end
      else
        raise InvalidCityState, "No location was found matching '#{obj}'"
      end
    end
    
    # this is plain text, is it a state?
    # TODO: Add another column to the cities table that lets us look up a city based on a nickname like 'san fran' which is translated into 'san francisco' which then does the normal location lookup
    if state = State.find_by_name_or_abbreviation(obj.downcase)
      @state = { :name => state.name, :abbreviation => state.abbreviation }
      return
    end
    
    # final check, is this a city?
    # TODO: Lowercase all city and state names so we can compare correctly
    if city = City.find_by_name(obj.downcase)
      if zips = Zip.find_all_by_city_and_state(city.name.titlecase, city.state.abbreviation.upcase)
        center = find_center_point_of(zips)
        # @zip = zips.collect { |zip| zip.zip }   # if it's a city/state then @zip contains an array of zips
        state = State.find_by_abbreviation(zips[0].state.downcase)
        @city = zips[0].city
        @state = { :name => state.name.titlecase, :abbreviation => state.abbreviation }
        @latitude = center[:latitude].to_f
        @longitude = center[:longitude].to_f
        @radius = options[:radius].to_f
        return
      end
    else
      raise InvalidLocation, "Could not find any city or state called '#{obj}'"
    end

  end
  
  # Returns a Hash with the center latitude and longitude given an array of Zip ActiveRecords
  def find_center_point_of(zips)
    unless zips.empty?
      average_latitude = 0
      average_longitude = 0
      zips.each do |zip| 
        average_latitude += zip.latitude
        average_longitude += zip.longitude
      end
      center_latitude = (((average_latitude / zips.length) * 10000).round / 10000).to_f
      center_longitude = (((average_longitude / zips.length) * 10000).round / 10000).to_f
    
      return { :latitude => center_latitude, :longitude => center_longitude }
    end
  end

end