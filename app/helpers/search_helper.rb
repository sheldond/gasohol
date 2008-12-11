module SearchHelper
  
  #
  # output the page links for a given number of results
  #
  def output_pages(from,to,total,results_per_page,query)
    
    current_page = to / results_per_page
    total_pages = total / results_per_page
    total_pages += 1 if total % results_per_page != 0
    
    count_from = 1
    count_to = total_pages > 7 ? 7 : total_pages

    # create a range with the from and to numbers, go through each and set as page
    links = (count_from..count_to).collect do |page|
      this_start = results_per_page * (page - 1)
      if from.to_i-1 == this_start        # current page?
        link_to(page.to_s, params.merge({:start => (this_start)}), { :class => 'current' })
      else
        link_to(page.to_s, params.merge({:start => (this_start)}))
      end
    end
    
    # turn into a standard list of links and add some dots if there are more than 7 pages
    output = links.join(' ')
    output += '...' if total_pages > 7
    return output
    
  end
  
  #
  # create star rating images and surrounding <div> based on a number passed in
  #
  def output_rating(num)
    output = '<div class="rating">'
    1.upto(num) { output += image_tag('/images/star_on.png', :title => "Average rating: #{num}") }    # rating
    num.upto(4) { output += image_tag('/images/star_off.png', :title => "Average rating: #{num}") }   # left-over grayed out stars
    output += '</div>'
    return output
  end
  
  def activity?(result)
    result[:meta][:category] == 'Activities'
  end
  
  #
  # return params that affect the search only (remove stuff like controller and action)
  #
  def good_params
    params.find_all do |key,value|
      key != 'controller' and key != 'action' and key != 'format'
    end
  end
  
  #
  # build the breadcrumb list by specifying what should be in each position
  #
  def build_breadcrumbs(params)
    # start as an array and then split with > later
    output = []
    output << params[:category].titlecase unless !params[:category] or params[:category].downcase == 'any'
    output << params[:sport].titlecase unless !params[:sport] or params[:sport].downcase == 'any'
    output << params[:type].titlecase unless !params[:type] or params[:type].downcase == 'any'
    output << params[:custom].titlecase unless !params[:custom] or params[:custom].downcase == 'any'
    output << params[:location] unless !params[:location] or params[:location] == ''
    output << "within #{params[:radius]} miles" unless !params[:radius] or params[:radius].downcase == 'any'
    output << "&apos;#{params[:q]}&apos;"
    output.join(' <span>&gt;</span> ')
  end
  
  #
  # return only the params that the 'all' search cares about (q, category, sport)
  #
  def all_search_params(without=nil)
    include_params = ['q','sport','category','action','controller','format','id']; include_params.delete(without.to_s)
    options = params.dup
    options.each do |key,value|
      unless(include_params.include? key)
        options.delete(key)
      end
    end
  end
  
  # Creates URLs for 'related items' searches. Both the ajax URL (returning JSON) and a full URL
  # that can be browsed to in order to see full results.
  #
  # result => Result object from GSA
  # options[:type] => What we want back from the search (count_only | full | short)
  # options[:category] => What we're searching for (:articles | :discussions | :training)
  # options[:q] => The keyword query. If it's blank then we figure it out in certain instances
  #
  # This code is very specific to our implementation which is why it's so hideously ugly. Different 
  # assets need to be searched in different ways, sometimes with 'inurl' if the asset has no meta data, 
  # otherwise with regular 'category' if it does.
  #
  # If one day all content, including discussions, are indexed and given the same meta data as events and
  # articles then this code can become much simpler.
  def related_search_url_for(result,options)
    
    path = ''
    parts = {}
    
    # is this just a count of articles or a full query URL?
    case options[:type]
    when :count_only
      path = url_for(:controller => 'search', :action => 'google', :format => 'json')
      parts[:num] = 1
    when :full
      path = url_for(:controller => 'search')
    when :short
      path = url_for(:controller => 'search', :action => 'google', :format => 'html')
      parts[:num] = 5
      parts[:style] = 'short'
    end
    
    # what type of content are we searching?
    case options[:category]
    when :training
      parts[:category] = 'Products'
      parts[:q] = options[:q] || ''
      
      unless options[:q]
        # add on inmeta values and OR them together so we get training plans for all media types, not just the first or last
        result[:meta][:media_types].each_with_index do |mt,i|
          if mt.values.first.match(/\\/)
            parts[:q] += "inmeta:mediaType~#{mt.values.first.split('\\').last}" if mt.values.first.match(/\\/)
            parts[:q] += ' OR ' if result[:meta][:media_types].length-1 != i
          end
        end
      end
    when :articles
      parts[:q] = options[:q] || '"' + format_title(result[:title]) + '"'
      parts[:category] = "Articles"
      parts[:inurl] = "active.com/*/Articles"
    when :discussions
      parts[:q] = options[:q] || '"' + format_title(result[:title]) + '"'
      parts[:inurl] = 'community.active.com'
    end
    
    url = path + '?' + parts.to_query
    return url.gsub(/%2B/,'+')  # to_query escapes our pluses into %2B so we need to change them back)
  
  end
  
  # Outputs the javascript for an ajax call to get related contextual stuff
  def ajax_for_context_related(category)
    ajax = related_search_url_for(nil, { :type => :short, :category => category, :q => params[:q] })
    link = related_search_url_for(nil, { :type => :full, :category => category, :q => params[:q] })

    output = <<END_OF_AJAX
    new Ajax.Request( "#{ajax}",
                      { evalscripts:true,
                        onSuccess:function(r) {
                          if(r.responseText.strip() == '') {
                            $('related_#{category.to_s}').remove()
                          } else {
                            $('related_#{category.to_s}').insert({'bottom':r.responseText});
                          }
                        },
                        onComplete:function() {
                          $('related_#{category.to_s}_indicator').remove();
                          $('related_#{category.to_s}').insert({'bottom':'<a href="#{link}" class="more">More #{category.to_s} &raquo;</a>'});
                        }
                      });
END_OF_AJAX
  end
  
  # Outputs the javascript for an ajax call to get related content for each search result.
  def ajax_for_result_related(result, type)
    ajax = related_search_url_for(result, { :type => :count_only, :category => type })
    link = related_search_url_for(result, { :type => :full, :category => type })
    
    case type
    when :training
      noun = 'training plan'
    when :discussions
      noun = 'discussion'
    when :articles
      noun = 'article'
    end

    output = <<END_OF_AJAX
    new Ajax.Request( "#{ajax}",
                      { evalscripts:true,
                        onSuccess:function(r) {
                          total = r.responseText.evalJSON().google.total_results
                          if(total > 0) {
                              $('result_#{result[:num]}_links_#{type}').insert({bottom:'<a href="#{link}">'+total+' #{noun}'+(total != 1 ? 's' : '')+'</a>'});
                            }
                          $('result_#{result[:num]}_indicator').remove();
                          }
                      });
END_OF_AJAX
  end
  
end
