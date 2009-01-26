module Gasohol
  class Result
  
    DEFAULT_RESULT = {  :num => 0, 
                        :mime => '', 
                        :level => 1, 
                        :url => '', 
                        :title => '', 
                        :abstract => '', 
                        :date => '', 
                        :meta => {}, 
                        :featured => false, 
                        :rating => 0 }
                      
    attr_reader :result,:num,:mime,:level,:url,:url_encoded,:title,:language,:abstract,:crawl_date,:has,:meta,:featured
  
    def initialize(xml)
      @result = Marshal.load(Marshal.dump(DEFAULT_RESULT))
      @num = xml.attributes['n'].to_i
      result[:num] = @num
      @mime = xml.attributes['mime'] || 'text/html'
      result[:mime] = @mime
      @level = xml.attributes['l'].to_i > 0 ? xml.attributes['l'].to_i : 1
      result[:level] = @level
      @url = xml.at(:u) ? xml.at(:u).inner_html : ''
      result[:url] = @url
      @url_encoded = xml.at(:ue) ? xml.at(:ue).inner_html : ''
      result[:url_encoded] = @url_encoded
      @title = xml.at(:t) ? xml.at(:t).inner_html : ''
      result[:title] = @title
      @language = xml.at(:lang) ? xml.at(:lang).inner_html : ''
      result[:language] = @language
      @abstract = xml.at(:s) ? xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
      result[:abstract] = @abstract
      # result[:date] = xml.at(:fs) ? Chronic.parse(xml.at(:fs)[:value]) : ''
      @crawl_date = xml.at(:crawldate) ? Chronic.parse(xml.at(:crawldate).inner_html) : ''
      result[:crawl_date] = @crawl_date
      if xml.at(:has)
        @has = {}
        if xml.at(:has).at(:c)
          @has[:cache] = {}
          result[:cache] = @has[:cache]
          @has[:cache][:size] = xml.at(:has).at(:c).attributes['sz']
          result[:cache][:size] = @has[:cache][:size]
          @has[:cache][:cid] =xml.at(:has).at(:c).attributes['cid']
          result[:cache][:cid] = @has[:cache][:cid]
          @has[:cache][:encoding] = xml.at(:has).at(:c).attributes['enc']
          result[:cache][:encoding] = @has[:cache][:encoding]
        end
      end
      @meta = {}
      @meta[:media_types] = []
      # result[:meta][:media_types] = []
      xml.search(:mt).each do |meta|
        tag = { meta.attributes['n'].underscore.to_sym => meta.attributes['v'].to_s.gsub(/\\/,'/') }
        if tag.key.to_s.match(/date/i)      # if this meta tag contains 'date' in the name somewhere, parse it
          @meta.merge!({ tag.key => Time.parse(tag.value) })
        else
          if tag.key == :media_type         # if this is a media_type then append to an array, otherwise just set the key/value
            @meta[:media_types] << tag
          else
            @meta.merge!(tag)
          end
        end
        result[:meta] = @meta
      end
      @featured = false
      result[:featured] = @featured
    
      @result = result
    end
    
    
    def to_h
      result.inspect
    end
  
  end
end