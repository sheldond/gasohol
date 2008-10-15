class Feature
  class << self
    def parse(xml)
      output = { :url => '', :title => '', :featured => true }
    
      output[:url] = xml.at(:gl) ? xml.at(:gl).inner_html : ''
      output[:title] = xml.at(:gd) ? xml.at(:gd).inner_html : ''

      return output
    end
  end
end