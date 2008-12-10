# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def un(text) 
    CGI::unescapeHTML(text)
  end
  
  def urlize(text)
    text.downcase.gsub(/[^0-9a-z_]/,'_').gsub(/_+/,'_')
  end
  
  def is_admin?
    @current_user and @current_user.is_admin ? true : false
  end
  
  # The title of an event usually looks something like: "Carlsbad <b>5000</b> | Carlsbad, CA 92081"
  # This method splits on the |, unescapes any escaped HTML, then removes the HTML tags, leaving
  # us with "Carlsbad 5000"
  def format_title(text)
    un(text.split("|").first.strip).gsub(/<.*?>/,'')
  end

end
