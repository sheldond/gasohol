# Any time we reference 'location' it should be an instance of this class.
# 'location' refers to an area to search. That can be within the radius of a zip code, an entire state
# or anything (the entire country)
class Location
  
  attr_accessor :zip, :city, :state, :latitude, :longitude
  
  def initialize
  end
  
end