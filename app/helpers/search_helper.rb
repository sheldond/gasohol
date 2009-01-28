module SearchHelper
  
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

  
  # take the array of media_types and turn them into a standard format that /search/related knows how to parse into useful data
  def format_media_types_for_training_plans(result)
    if result.meta && result.meta[:media_type]
      output = ''
      result.meta[:media_type].each_with_index do |mt,i|
        if mt.match(/\//)
          output += mt.split('/').last
          output += '|' if result.meta[:media_type].length-1 != i
        end
      end
      return output
    end
  end
  
end
