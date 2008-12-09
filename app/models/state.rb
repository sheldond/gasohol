class State < ActiveRecord::Base
  
  def self.find_by_name_or_abbreviation(text)
    text.downcase!
    find(:first, :conditions => ['name = ? or abbreviation = ?',text,text])
  end
end
