class Feature
    
  attr_accessor :url, :title, :xml, :featured
  
  def initialize(xml_string)
    @xml = xml_string
    parse
  end
  
  def to_s
    puts "url => " + @url + ", title => " + @title
  end
  
  private
  def parse
    @url = @xml.at(:gl) ? @xml.at(:gl).inner_html : ''
    @title = @xml.at(:gd) ? @xml.at(:gd).inner_html : ''
    @featured = true
  end
  
end