module Gasohol
  class ResultSet
                        
    attr_reader :google_query, :full_query_path, :total_results, :total_featured_results, :params, :results, :featured, :from_num, :to_num
    attr_reader :total_pages, :current_page, :previous_page, :next_page   # for will_paginate plugin
    attr_writer :total_featured_results, :results, :featured
    
    def initialize(query,full_query_path,xml,num_per_page)
      @google_query = query
      @full_query_path = full_query_path
      @total_results = xml.search(:m).inner_html.to_i || 0
      if xml.search(:res).first
        @from_num = xml.search(:res).first.attributes['sn'].to_i
        @to_num = xml.search(:res).first.attributes['en'].to_i
      end
      @params = {}
      xml.search(:param).each do |param|
        @params.merge!({param.attributes['name'].to_sym => param.attributes['value'].to_s})
      end
      @total_featured_results = 0
      @featured = []
      @results = []

      # for will_paginate plugin
      @total_pages = (@total_results.to_f / num_per_page).ceil
      @current_page = (@from_num.to_f / num_per_page).ceil
      @previous_page = (@current_page - 1 == 0) ? nil : @current_page - 1
      @next_page = (@current_page + 1 > @total_pages) ? nil : @current_page + 1

    end
    
  end
end