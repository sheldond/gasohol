class Invite < ActiveRecord::Base
  
  has_many :users
  
  validates_presence_of :code, :available
  validates_uniqueness_of :code
  validates_numericality_of :available, :used
  
  def validate
    if self.available && self.available <= 0
      self.errors.add :available, 'must be greater than zero'
    end
  end
  
  def before_save
    self.code.downcase!
  end
  
end
