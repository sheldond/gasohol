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
  
  
  # determines what type of 'thing' the passed result is. Since each media type can be displayed different, this
  # has a lot of ugly logic to determine what type of thing the result is. There should be one return for each file
  # in /app/views/search/results
  def result_type(result)
    return 'activity' if result[:meta][:category] && result[:meta][:category] == 'Activities'
    return 'article' if result[:meta][:category] && result[:meta][:category] == 'Articles'
    return 'community' if result[:url].match(/community\.active\.com/)
    return 'facility' if result[:meta][:category] && result[:meta][:category] == 'Facilities'
    return 'org' if result[:meta][:category] && result[:meta][:category] == 'Organizations'
    return 'training' if result[:meta][:media_types][0] && result[:meta][:media_types][0].value.match(/Training Plan/)
    # if nothing else, just return 'unknown'
    return 'unknown'
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
    output << SearchController::SEARCH_MODES.find { |mode| mode[:mode] == params[:mode] }[:name].titlecase unless !params[:mode] or params[:mode].downcase == 'any'
    output << params[:sport].titlecase unless !params[:sport] or params[:sport].downcase == 'any'
    output << params[:difficulty].titlecase unless !params[:difficulty] or params[:difficulty] == 'any'
    output << params[:type].titlecase unless !params[:type] or params[:type].downcase == 'any'
    output << params[:custom].titlecase unless !params[:custom] or params[:custom].downcase == ''
    if location_aware_search_mode?(params[:mode])
      output << params[:location] unless !params[:location] or params[:location] == ''
    end
    # TODO: properly show search radius
    #output << "within #{params[:radius]} miles" unless !params[:radius] or params[:radius].downcase == 'any'
    output << "#{google_query_to_keywords params[:q]}"
    output.join(' <span>&gt;</span> ')
  end
  
  
  # says whether or not the passed mode is one that cares about location
  def location_aware_search_mode?(text)
    return SearchController::LOCATION_AWARE_SEARCH_MODES.include?(text)
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
  
  
  def format_media_types_for_training_plans(result)
    if result[:meta] && result[:meta][:media_types]
      output = ''
      result[:meta][:media_types].each_with_index do |mt,i|
        if mt.value.match(/\//)
          output += mt.value.split('/').last
          output += '|' if result[:meta][:media_types].length-1 != i
        end
      end
      return output
    end
  end
  
end
