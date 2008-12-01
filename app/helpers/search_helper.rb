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
  
end
