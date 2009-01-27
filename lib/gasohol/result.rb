module Gasohol
  class Result
  
    attr_reader :result,:num,:mime,:level,:url,:url_encoded,:title,:language,:abstract,:crawl_date,:has,:meta,:featured
  
    def initialize(xml)
      @num = xml.attributes['n'].to_i
      @mime = xml.attributes['mime'] || 'text/html'
      @level = xml.attributes['l'].to_i > 0 ? xml.attributes['l'].to_i : 1
      @url = xml.at(:u) ? xml.at(:u).inner_html : ''
      @url_encoded = xml.at(:ue) ? xml.at(:ue).inner_html : ''
      @title = xml.at(:t) ? xml.at(:t).inner_html : ''
      @language = xml.at(:lang) ? xml.at(:lang).inner_html : ''
      @abstract = xml.at(:s) ? xml.at(:s).inner_html.gsub(/&lt;br&gt;/i,'').gsub(/\.\.\./,'') : ''
      # result[:date] = xml.at(:fs) ? Chronic.parse(xml.at(:fs)[:value]) : ''
      @crawl_date = xml.at(:crawldate) ? Chronic.parse(xml.at(:crawldate).inner_html) : ''
      if xml.at(:has)
        @has = {}
        if xml.at(:has).at(:c)
          @has[:cache] = {}
          @has[:cache][:size] = xml.at(:has).at(:c).attributes['sz']
          @has[:cache][:cid] =xml.at(:has).at(:c).attributes['cid']
          @has[:cache][:encoding] = xml.at(:has).at(:c).attributes['enc']
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
      end
      @featured = false
    end
    
    
    # what type of result is this?
    def type
      return :activity if @meta[:category] && @meta[:category] == 'Activities'
      return :article if @meta[:category] && @meta[:category] == 'Articles'
      return :community if @url.match(/community\.active\.com/)
      return :facility if @meta[:category] && @meta[:category] == 'Facilities'
      return :org if @meta[:category] && @meta[:category] == 'Organizations'
      return :training if @meta[:media_types][0] && @meta[:media_types][0].value.match(/Training Plan/)
      # if nothing else, just return 'unknown'
      return 'unknown'
    end


    # individual type checks
    def activity?
      type == :activity
    end
    
    def article?
      type == :article
    end
    
    def community?
      type == :community
    end
    
    def facility?
      type == :facility
    end
    
    def org?
      type == :org
    end
    
    def training?
      type == :training
    end
    
    def unknown?
      type == :unknown
    end
    
  
  end
end