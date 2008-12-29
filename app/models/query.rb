require 'chronic'

class Query < ActiveRecord::Base

  self.inheritance_column = 'none'
  
  def self.record(query=nil,options=nil)
    
    opts = options.dup
    # official options that we care about
    [:location,:sport,:start_date,:end_date,:type,:custom,:category].each do |part|
      opts[part] = nil if opts[part] == ''
      if part == :start_date || part == :end_date
        opts[part] = Chronic.parse(opts[part]).strftime('%Y-%m-%d 00:00:00') unless opts[part].nil?
      else
        opts[part] = opts[part].to_s unless opts[part].nil?
      end
    end
    
    record = self.find_or_create_by_keywords_and_category_and_location_and_sport_and_start_date_and_end_date_and_type_and_custom(query, opts[:category], opts[:location], opts[:sport], opts[:start_date], opts[:end_date], opts[:type], opts[:custom])
    record.count += 1
    record.save

  end
  
  def self.find_popular(num=5)
    # select keywords, sum(`count`) as count from queries where location = 'San Diego, California' group by keywords order by count desc;
    find_by_sql(["select *, sum(count) as total \
                  from queries \
                  where keywords != '' \
                  group by keywords, sport, type, custom \
                  order by total desc \
                  limit ?", num])
  end
  
  def self.find_popular_by_location(location,num=5)
    # if this is a hash, get the city and state out, otherwise assume it's a valid location string
    find_by_sql(["select *, sum(count) as total \
                  from queries \
                  where location = ? and keywords != '' and keywords not like '%inmeta%' and keywords not like '%inurl%' \
                  group by keywords \
                  order by total desc \
                  limit ?", location.form_value, num])
  end
  
  def self.find_related_by_location(text,location,num=5)
    # if this is a hash, get the city and state out, otherwise assume it's a valid location string
    find_by_sql(["select *, sum(count) as total \
                  from queries \
                  where location = ? and keywords like ? and keywords not like '%inmeta%' and keywords not like '%inurl%' and keywords != ? \
                  group by keywords \
                  order by total desc \
                  limit ?", location.form_value, "%#{text}%", text, num])
  end
  
end
