class SearchController < ApplicationController

  def index
    
  end

  def search
    @response = Google.new(params[:q], :num => params[:num], :start => params[:start])
  end

end
