require 'chronic'

class Result
    
  attr_accessor :url, :title, :abstract, :date, :xml, :num, :mime, :level
  
  def initialize(xml_string)
    @xml = xml_string
    parse
  end
  
  def to_s
    puts "num => " + @num.to_s + ", url => " + @url + ", title => " + @title
  end
  
  private
  def parse
    @num = @xml.attributes['n'].to_i
    @mime = @xml.attributes['mime'] || 'text/html'
    @level = @xml.attributes['l'].to_i > 0 ? @xml.attributes['l'].to_i : 1
    @url = @xml.at(:u) ? @xml.at(:u).inner_html : ''
    @title = @xml.at(:t) ? @xml.at(:t).inner_html : ''
    @abstract = @xml.at(:s) ? @xml.at(:s).inner_html : ''
    @date = Chronic.parse(@xml.at(:fs)[:value])
  end
  
end