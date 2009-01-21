require 'chronic'

class Query < ActiveRecord::Base

  self.inheritance_column = 'none'
  belongs_to :user
  
  def self.new_with_original_params(params)
     Query.new( :original_keywords => params[:q], 
                :original_location => params[:location] || '',
                :start => params[:start] || 1,
                :original_start_date => params[:start_date] || '',
                :original_end_date => params[:end_date] || '')
  end
  
  def update_with_options(params={})
    
    self.keywords = params[:q]
    
    opts = params.dup
    [:location,:sport,:start_date,:end_date,:type,:custom,:mode].each do |part|
      # prepare the value of each to be something the database likes
      opts[part] = nil if opts[part] == ''
      if part == :start_date || part == :end_date
        opts[part] = Chronic.parse(opts[part]).strftime('%Y-%m-%d 00:00:00') unless opts[part].nil?
      else
        opts[part] = opts[part].to_s unless opts[part].nil?
      end
      # set all the parts to the requisite parts of the query
      self.send("#{part.to_s}=",opts[part])
    end
    
    return self
    
  end
  
  # Top searches anywhere
  def self.find_popular(num=5)
    # select keywords, sum(`count`) as count from queries where location = 'San Diego, California' group by keywords order by count desc;
    find_by_sql(["select *, count(*) as total \
                  from queries \
                  where keywords != '' \
                  group by keywords, sport, type, custom \
                  order by total desc \
                  limit ?", num])
  end
  
  
  # Top searches in the same location
  def self.find_popular_by_location(location,num=5)
    find_by_sql(["select *, count(*) as total \
                  from queries \
                  where location = ? and keywords != '' and keywords not like '%inmeta%' and keywords not like '%inurl%' \
                  group by keywords \
                  order by total desc \
                  limit ?", location.form_value, num])
  end
  
  # Top searches that contain some keyword in the same location
  def self.find_related_by_location(text,location,num=5)
    find_by_sql(["select *, sum(count) as total \
                  from queries \
                  where location = ? and keywords like ? and keywords not like '%inmeta%' and keywords not like '%inurl%' and keywords != ? \
                  group by keywords \
                  order by total desc \
                  limit ?", location.form_value, "%#{text}%", text, num])
  end
  
end
