class Result
  
  DEFAULT_OUTPUT = { :num => 0, :mime => '', :level => 1, :url => '', :title => '', :abstract => '', :date => '', :meta => {}, :featured => false, :rating => 0 }
  
  class << self
    def parse(xml)
      output = DEFAULT_OUTPUT
      output[:num] = xml.attributes['n'].to_i
      output[:mime] = xml.attributes['mime'] || 'text/html'
      output[:level] = xml.attributes['l'].to_i > 0 ? xml.attributes['l'].to_i : 1
      output[:url] = xml.at(:u) ? xml.at(:u).inner_html : ''
      output[:title] = xml.at(:t) ? xml.at(:t).inner_html : ''
      output[:abstract] = xml.at(:s) ? xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
      output[:date] = xml.at(:fs) ? Chronic.parse(xml.at(:fs)[:value]) : ''
      xml.search(:mt).each do |meta|
        if meta.attributes['n'].match(/date/i)
          output[:meta].merge!({ meta.attributes['n'].underscore.to_sym => Chronic.parse(meta.attributes['v']) })
        else
          output[:meta].merge!({ meta.attributes['n'].underscore.to_sym => meta.attributes['v'].to_s })
        end
      end
      output[:featured] = false
      if rand(3) < 2
        output[:rating] = rand(5)
      end
      return output
    end
  end
end