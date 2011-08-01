class SearchController < ApplicationController
  include WikiCloth
    
  def index
    render :json => WikiDb::Database.new.search(params[:term])[0, WikiDb.max_search_results]
  end
end
