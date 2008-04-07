require 'hpricot'
require 'open-uri'

class Google
  
  SEARCH_URL = 'http://gsa17.enterprisedemo-google.com/search'
  DEFAULTS = {:num => 10, :start => 0}
  
  attr_accessor :query, :xml, :total_results, :results, :next, :prev
  
  def initialize(query, options=DEFAULTS)
    options = DEFAULTS.merge(options)
    search(query,options)
  end
  
  def search(query,options)
    @query = query.to_s
    @xml = Hpricot(open(SEARCH_URL + "?q=#{@query}&output=xml_no_dtd&client=default_frontend&num=#{options[:num].to_s}&start=#{options[:start].to_s}"))
    @total_results = @xml.search(:m).inner_html.to_i
    @results = []
    @xml.search(:r).each do |xml_result|
      @results << Result.new(xml_result)
    end
    @next = @results.last.num unless @total_results < @results.last.num + DEFAULTS[:num] - 1
    @prev = @results.first.num - DEFAULTS[:num] - 1 unless @results.first.num == 1
  end
  
end
