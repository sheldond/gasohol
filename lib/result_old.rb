require 'chronic'

class Result
    
  attr_accessor :url, :title, :abstract, :date, :xml, :num, :mime, :level, :featured, :meta
  
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
    @abstract = @xml.at(:s) ? @xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
    @date = @xml.at(:fs) ? Chronic.parse(@xml.at(:fs)[:value]) : ''
    @meta = {}
    @xml.search(:mt).each do |meta|
      @meta.merge!({ meta.attributes['n'].to_sym => meta.attributes['v'].to_s })
    end
    @featured = false
  end
  
end