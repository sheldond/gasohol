module Gasohol
  class Featured
    
    attr_reader :url, :title
    
    def initialize(xml)
      @url = xml.at(:gl) ? xml.at(:gl).inner_html : ''
      @title = xml.at(:gd) ? xml.at(:gd).inner_html : ''
    end
    
  end
end

=begin
# a featured result
def parse_featured_result(xml)
  result = Marshal.load(Marshal.dump(DEFAULT_FEATURED_RESULT))
  result[:url] = xml.at(:gl) ? xml.at(:gl).inner_html : ''
  result[:title] = xml.at(:gd) ? xml.at(:gd).inner_html : ''
  return result
end
=end