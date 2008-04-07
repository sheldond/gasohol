require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'chronic'

class Google
  
  SEARCH_URL = 'http://gsa17.enterprisedemo-google.com/search'
  DEFAULTS = {:num => 10, :start => 1}
  
  attr_accessor :query, :xml, :total_results, :results
  
  def initialize(query, options=DEFAULTS)
    options = DEFAULTS.merge(options)
    search(query,options)
  end
  
  def search(query,options)
    @query = query.to_s
    @xml = Hpricot(open(SEARCH_URL + "?q=#{@query}&output=xml_no_dtd&client=default_frontend&num=#{options[:num].to_s}&start=#{options[:start].to_s}"))
    @total_results = @xml.search(:m).inner_html.to_i
    results = []
    @xml.search(:r).each do |xml_result|
      results << Result.new(xml_result)
    end
    @results = results
  end
  
end


class Result
    
  attr_accessor :url, :title, :abstract, :date, :xml, :num, :mime, :level
  
  def initialize(xml_string)
    @xml = xml_string
    parse
  end
  
  def to_s
    puts "num => " + @num.to_s
    puts "mime => " + @mime
    puts "level => " + @level.to_s
    puts "url => " + @url
    puts "title => " + @title
    puts "abstract => " + @abstract
    puts "date => " + @date.to_s
  end
  
  private
  def parse
    @num = @xml.attributes['n'].to_i
    @mime = @xml.attributes['mime'] || 'text/html'
    @level = @xml.attributes['l'].to_i > 0 ? @xml.attributes['l'].to_i : 1
    @url = @xml.at(:u).inner_html
    @title = @xml.at(:t).inner_html
    @abstract = @xml.at(:s).inner_html
    @date = Chronic.parse(@xml.at(:fs)[:value])
  end
  
end

print 'Search for: '
search = gets.chomp
results = Google.new(search, :num => 15, :start => 1)

puts results.total_results.to_s + ' results'