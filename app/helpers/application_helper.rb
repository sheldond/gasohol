# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def logged_in?
    !session[:user].nil?
  end
  
  # Request from an iPhone or iPod touch? (Mobile Safari user agent)
  def iphone_user_agent?
    request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/(Mobile\/.+Safari)/]
  end

  # Shorter way to call CGI::unescapeHTML
  def un(text) 
    CGI::unescapeHTML(text)
  end
  
  # Turns a string into a URL part, ie. I love url-encoding => i_love_url_encoding
  def urlize(text)
    text.downcase.gsub(/[^0-9a-z_]/,'_').gsub(/_+/,'_')
  end
  
  # Is the currently logged in user an administrator?
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
