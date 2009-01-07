class Flag < ActiveRecord::Base
  
  belongs_to :user
  
  validates_presence_of :user_id, :asset_id
  
end
