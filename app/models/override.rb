class Override < ActiveRecord::Base
  
  self.inheritance_column = 'none'
  
  def to_options
    options = {}
    self.class.column_names.collect do |name|
      if name != 'id' && name != 'keywords' && !self.send(name).blank? 
        options.merge!({ name.to_sym => self.send(name) })
      end
    end
    
    return options
    
  end
  
end
