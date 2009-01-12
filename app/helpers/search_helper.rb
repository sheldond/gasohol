module SearchHelper
  
  # Output the page links for a given number of results
  def output_pages(from,to,total,results_per_page,query)
    results_per_page = results_per_page.to_i
    
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
  
  def google_query_to_keywords(text)
    h(text.match(/^(.*?)(inmeta.*)?$/)[1].strip)
  end
  
  # Create star rating images and surrounding <div> based on a number passed in
  def output_rating(num)
    output = '<div class="rating">'
    1.upto(num) { output += image_tag('/images/star_on.png', :title => "Average rating: #{num}") }    # rating
    num.upto(4) { output += image_tag('/images/star_off.png', :title => "Average rating: #{num}") }   # left-over grayed out stars
    output += '</div>'
    return output
  end
  
  # Determines if the passed result is an activity
  def activity?(result)
    result[:meta][:category] && result[:meta][:category] == 'Activities'
  end
  
  # Determines if the passed result is a training plan
  def training?(result)
    result[:meta][:media_types][0] && result[:meta][:media_types][0].value.match(/Training Plan/)
  end
  
  # Determines if the passed result is an article
  def article?(result)
    result[:meta][:category] == 'Articles'
  end
  
  # Return params that affect the search only (remove stuff like controller and action)
  def good_params
    params.find_all do |key,value|
      key != 'controller' and key != 'action' and key != 'format'
    end
  end
  
  # Given the params in the URL, build a breadcrumb with all the parts
  def build_breadcrumbs(params)
    output = []
    output << params[:category].titlecase unless !params[:category] or params[:category].downcase == 'any'
    output << params[:sport].titlecase unless !params[:sport] or params[:sport].downcase == 'any'
    output << params[:type].titlecase unless !params[:type] or params[:type].downcase == 'any'
    output << params[:custom].titlecase unless !params[:custom] or params[:custom].downcase == ''
    output << params[:location] unless !params[:location] or params[:location] == ''
    output << "within #{params[:radius]} miles" unless !params[:radius] or params[:radius].downcase == 'any'
    output << "#{google_query_to_keywords params[:q]}"
    output.join(' <span>&gt;</span> ')
  end
  
  # Return only the params that the 'all' search cares about (q, category, sport)
  def all_search_params(without=nil)
    include_params = ['q','sport','category','action','controller','format','id']; include_params.delete(without.to_s)
    options = params.dup
    options.each do |key,value|
      unless(include_params.include? key)
        options.delete(key)
      end
    end
  end
  
  # Creates URLs for 'related items' searches. 
  #
  # * result => Result object from GSA
  # * options[:type] => What we want back from the search (count_only | full | short)
  # * options[:category] => What we're searching for (:articles | :discussions | :training)
  # * options[:q] => The keyword query. If it's blank then we figure it out in certain instances
  #
  # options[:type]s are broken down into:
  #
  # * count_only => a URL that returns only 1 result, and all we really care about is the total number of results
  # * full => a URL to a regular search
  # * short => a URL that pulls back only the titles of the top 5 results
  #
  # This code is very specific to our implementation which is why it's so hideously ugly. Different 
  # assets need to be searched in different ways, sometimes with 'inurl' if the asset has no meta data, 
  # otherwise with regular 'category' if it does.
  #
  # If one day all content, including discussions, are indexed and given the same meta data as events and
  # articles then this code can become much simpler and prettier.
  def related_search_url_for(result,options,additional_parts={})
    
    path = ''
    parts = {}.merge!(additional_parts)
    
    # what kind of URL are we looking for?
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
          parts[:partialfields] ||= ''
          if mt.value.match(/\\/)
            parts[:partialfields] += "mediaType:#{mt.value.split('\\').last}"
            parts[:partialfields] += '|' if result[:meta][:media_types].length-1 != i
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
    
  end
  
  # Outputs the javascript for an ajax call to get related contextual links (currently shown in the right column)
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
  def ajax_for_result_related(result)
    formatted_title = format_title(result[:title]).gsub(/&.*?;/,'').gsub(/-.*$/,'').gsub(/[^\w ]/,'').strip
    output = {:id => result[:num], :calls => []}
    
    output[:calls] << { :noun => 'training plan',
                        :name => 'training',
                        :type => 'google',
                        :ajax => CGI::escape(related_search_url_for(result, { :type => :count_only, :category => :training }, :count_only => true )),
                        :link => CGI::escape(related_search_url_for(result, { :type => :full, :category => :training })) }
    output[:calls] << { :noun => 'discussion',
                        :name => 'discussions',
                        :type => 'google',
                        :ajax => CGI::escape(related_search_url_for(result, { :type => :count_only, :category => :discussions }, :count_only => true )),
                        :link => CGI::escape(related_search_url_for(result, { :type => :full, :category => :discussions })) }
    output[:calls] << { :noun => 'article',
                        :name => 'articles',
                        :type => 'google',
                        :ajax => CGI::escape(related_search_url_for(result, { :type => :count_only, :category => :articles }, :count_only => true )),
                        :link => CGI::escape(related_search_url_for(result, { :type => :full, :category => :articles })) }
    output[:calls] << { :noun => 'photo',
                        :name => 'photos',
                        :type => 'photos',
                        :ajax => CGI::escape("http://api.flickr.com/services/rest?text=#{CGI::escape(formatted_title)}&api_key=4998fab76787cf39383c563b32ce4b8f&method=flickr.photos.search&sort=relevance&format=json&nojsoncallback=1"),
                        :link => CGI::escape("http://flickr.com/search/?w=all&m=text&q=#{CGI::escape(formatted_title)}") }     
    output[:calls] << { :noun => 'video',
                        :name => 'videos',
                        :type => 'videos',
                        :ajax => CGI::escape("http://gdata.youtube.com/feeds/api/videos?vq=#{CGI::escape(formatted_title)}&max-results=1&alt=json"),
                        :link => CGI::escape("http://www.youtube.com/results?search_query=#{CGI::escape(formatted_title)}&search_type=&aq=f") }
    output[:calls] << { :noun => 'tweet',
                        :name => 'tweets',
                        :type => 'tweets',
                        :ajax => CGI::escape("http://search.twitter.com/search.json?q=#{CGI::escape(formatted_title)}"),
                        :link => CGI::escape("http://search.twitter.com/search?q=#{CGI::escape(formatted_title)}") }
    output = <<END_OF_AJAX
    
    new Ajax.Request( "#{url_for(:controller => 'search', :action => 'related')}",
                      { evalJS:true,
                        method:'post',
                        parameters:'request=#{output.to_json}',
                        onSuccess:function(r) {
                          $('result_#{result[:num]}_indicator') ? $('result_#{result[:num]}_indicator').remove() : null;
                        },
                        onFailure:function(e) {
                          $('result_#{result[:num]}_indicator').remove();
                        }
                      });
END_OF_AJAX
  end
  
end
