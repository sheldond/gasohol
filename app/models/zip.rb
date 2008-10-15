class Zip < ActiveRecord::Base
  
  set_inheritance_column :none
  
  def self.find_within_radius(zip,radius)
    this_zip = find_by_zip(zip)
    radius = radius.to_i
    latitude1 = this_zip.latitude - (radius / 69.1)
    latitude2 = this_zip.latitude + (radius / 69.1 )
    longitude1 = this_zip.longitude - (radius / (69.1 * Math.cos(this_zip.latitude/57.3)) )
    longitude2 = this_zip.longitude + (radius / (69.1 * Math.cos(this_zip.latitude/57.3)) )
    find_by_sql("SELECT * FROM zips WHERE latitude >= #{latitude1} AND latitude <= #{latitude2} AND longitude >= #{longitude1} AND longitude <= #{longitude2}")
  end
  
end