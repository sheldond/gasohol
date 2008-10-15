# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def un(text) 
    CGI::unescapeHTML(text)
  end
  
  def urlize(text)
    text.downcase.gsub(/[^0-9a-z_]/,'_').gsub(/_+/,'_')
  end

end
