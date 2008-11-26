class Query < ActiveRecord::Base
  
  self.inheritance_column = 'none'
  
  def self.record(query=nil,options=nil)
    
    opts = options.dup
    # official options that we care about
    [:location,:sport,:start_date,:end_date,:type,:custom].each do |part|
      opts[part] = nil if opts[part] == ''
      if part == :start_date || part == :end_date
        opts[part] = Chronic.parse(opts[part]).strftime('%Y-%m-%d 00:00:00') unless opts[part].nil?
      else
        opts[part] = opts[part].to_s unless opts[part].nil?
      end
    end
    
    record = self.find_or_create_by_keywords_and_location_and_sport_and_start_date_and_end_date_and_type_and_custom(query, opts[:location], opts[:sport], opts[:start_date], opts[:end_date], opts[:type], opts[:custom])
    record.count += 1
    record.save

  end
  
  def self.find_popular(num=5)
    
  end
  
end
