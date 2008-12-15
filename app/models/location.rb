# Any time we reference 'location' it should be an instance of this class.
# 'location' refers to an area to search. That can be within the radius of a zip code, an entire state
# or anything (the entire country)
class Location
  
  include Exceptions
  
  DEFAULT_OPTIONS = { :radius => 50 }
  ANYWHERE_PHRASES = ['anywhere','everywhere','any']
  
  attr_reader :zip, :city, :state, :latitude, :longitude, :radius, :everywhere
  
  def initialize(obj,options={})
    options = DEFAULT_OPTIONS.merge!(options)
    @zip, @city, @state, @latitude, @longitude, @radius = nil
    @everywhere = false
    
    begin
      parse(obj,options)
    # rescue
      # if there are any errors finding the location, just default it to everywhere
    #  @everywhere = true
    end
  end
  
  # alias 'new' as 'from_cookie' if we are creating a new Location from a cookie
  def self.from_cookie(obj,options={})
    new(obj,options)
  end
  
  def empty?
    return (@zip.nil? && @city.nil? && @state.nil? && !@everywhere) ? true : false
  end
  
  # return a Hash version
  def to_h
    { :zip => @zip,
      :city => @city,
      :state => @state,
      :latitude => @latitude,
      :longitude => @longitude,
      :radius => @radius,
      :everywhere => @everywhere }
  end
  
  # return a Hash version encoded into JSON
  def to_cookie
    self.to_h.to_json
  end
  
  # is this a state-only search?
  def only_state?
    return (@state && @city.nil? && @zip.nil?) ? true : false
  end
  
  private
  
  # Does the work of actually parsing the text passed in and figuring out what this is supposed to be
  def parse(obj,options)
    
    # this is already a valid location hash
    if (ActiveSupport::JSON.decode(obj)).is_a? Hash
      @zip = obj['zip']
      @city = obj['city']
      @state = obj['state']
      @latitude = obj['latitude']
      @longitude = obj['longitude']
      @radius = obj['longitude']
      @everywhere = obj['everywhere']
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
      zip = Zip.find_by_zip(obj)
      if zip
        @zip = zip.zip
        @city = zip.city
        @state = zip.state
        @latitude = zip.latitude
        @longitude = zip.longitude
        @radius = options[:radius]
        return
      else
        raise InvalidZip, "Zip code '#{obj}' was not found."
      end
    end
    
    # city or state or city,state
    if obj.split(',').length > 1   # in the form of city,state
      city,state = obj.split(',').each { |part| part.strip! }
      state = State.find_by_name_or_abbreviation(state)
      zips = Zip.find_all_by_city_and_state(city.titlecase, state.abbreviation.upcase)
      if zips
        center = find_center_point_of(zips)
        # @zip = zips.collect { |zip| zip.zip }   # if it's a city/state then @zip contains an array of zips
        @city = zips[0].city
        @state = zips[0].state
        @latitude = center[:latitude]
        @longitude = center[:longitude]
        @radius = options[:radius]
        return
      else
        raise InvalidCityState, "No location was found matching '#{obj}'"
      end
    end
    
    # if we got this far then this is plain text and either a city or state name
    state = State.find_by_name_or_abbreviation(obj.downcase)
    city = City.find_by_name(obj.downcase)
    
    if state
      @state = state.name
      return
    elsif city
      zips = Zip.find_all_by_city_and_state(city.name.titlecase, city.state.abbreviation.upcase)
      if zips
        center = find_center_point_of(zips)
        # @zip = zips.collect { |zip| zip.zip }   # if it's a city/state then @zip contains an array of zips
        @city = zips[0].city
        @state = zips[0].state
        @latitude = center[:latitude]
        @longitude = center[:longitude]
        @radius = options[:radius]
        return
      end
    else
      raise InvalidLocation, "Could not find any city or state called '#{obj}'"
    end

  end
  
  # Returns a Hash with the center latitude and longitude given an array of Zip ActiveRecords
  def find_center_point_of(zips)
    average_latitude = 0
    average_longitude = 0
    zips.each do |zip| 
      average_latitude += zip.latitude
      average_longitude += zip.longitude
    end
    center_latitude = ((average_latitude / zips.length) * 10000).round / 10000
    center_longitude = ((average_longitude / zips.length) * 10000).round / 10000
    
    return { :latitude => center_latitude, :longitude => center_longitude }
  end

end