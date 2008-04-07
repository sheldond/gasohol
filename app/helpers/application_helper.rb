# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def un(text) 
    CGI::unescapeHTML(text)
  end

end
