class City < ActiveRecord::Base
  
  belongs_to :state
  
  validates_uniqueness_of :name
  validates_presence_of :name
  
end
