require 'chronic'

class Query < ActiveRecord::Base
  
  FIND_POPULAR_STARTING_ON = 7.days.ago.strftime('%Y-%m-%d 00:00:00')

  self.inheritance_column = 'none'
  belongs_to :user
  
  def self.new_with_original_params(params, values={})
    query = self.new( :original_keywords => params[:q], 
                      :original_location => params[:location] || '',
                      :start => params[:start] || 1,
                      :original_start_date => params[:start_date] || '',
                      :original_end_date => params[:end_date] || '')
    
    unless values.empty?
      values.each do |key,value|
        self.send("#{key.to_s}=",value)
      end
    end
    
    return query
                
  end
  
  
  # add some more params, parsing if needed, then save
  def update_with_options(params={}, values={})
    
    self.keywords = params[:q]
    
    opts = params.dup
    [:location,:sport,:start_date,:end_date,:type,:custom,:mode,:radius,:view].each do |part|
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
    
    # extra values that were passed in as a hash
    unless values.empty?
      values.each do |key,value|
        self.send("#{key.to_s}=",value)
      end
    end
    
    self.save
    
  end
  
  
  # Top searches anywhere
  def self.find_popular(num=5)
    # select keywords, sum(`count`) as count from queries where location = 'San Diego, California' group by keywords order by count desc;
    find(:all, :select => '*, count(*) as total',
               :conditions => "keywords != '' and created_at > '#{FIND_POPULAR_STARTING_ON}'",
               :group => "keywords, sport, type, custom",
               :order => "total desc",
               :limit => num)
  end
  
  
  # Top searches in the same location
  def self.find_popular_by_mode(mode,num=5)
    find(:all, :select => "*, count(*) as total",
               :conditions => ["mode = ? and keywords != '' and keywords not like '%inmeta%' and keywords not like '%inurl%' and created_at > ?", mode, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
  
  # Top searches in the same location
  def self.find_popular_by_location(location,num=5)
    find(:all, :select => "*, count(*) as total",
               :conditions => ["location = ? and keywords != '' and keywords not like '%inmeta%' and keywords not like '%inurl%' and created_at > ?", location.form_value, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
  
  # Top searches in the same location for this type of asset
  def self.find_popular_by_location_and_mode(location,mode,num=5)
    find(:all, :select => "*, count(*) as total",
               :conditions => ["mode = ? and location = ? and keywords != '' and keywords not like '%inmeta%' and keywords not like '%inurl%' and created_at > ?", mode, location.form_value, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
  
  
  def self.find_related_by_mode(text,mode,num=5)
    find(:all, :select => "*, sum(count) as total",
               :conditions => ["mode = ? and keywords like ? and keywords not like '%inmeta%' and keywords not like '%inurl%' and keywords != ? and created_at > ?",  mode, "%#{text}%", text, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
  def self.find_related_by_location(text,location,num=5)
    find(:all, :select => "*, sum(count) as total",
               :conditions => ["mode = ? and keywords like ? and keywords not like '%inmeta%' and keywords not like '%inurl%' and keywords != ? and created_at > ?",location.form_value, "%#{text}%", text, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
  # Top searches that contain some keyword in the same location
  def self.find_related_by_location_and_mode(text,location,mode,num=5)
    find(:all, :select => "*, sum(count) as total",
               :conditions => ["mode = ? and location = ? and keywords like ? and keywords not like '%inmeta%' and keywords not like '%inurl%' and keywords != ? and created_at > ?", mode, location.form_value, "%#{text}%", text, FIND_POPULAR_STARTING_ON],
               :group => 'keywords',
               :order => 'total desc',
               :limit => num)
  end
  
end
