# Extends Gasohol's ResultSet object so that we can store the original params that were sent in
# before they (potentially) are modified by the code in ActiveSearch::search

class ActiveResultSet < Gasohol::ResultSet
  
  attr_reader :original_params, :modified_params
  
  def initialize(query,full_query_path,xml,num_per_page,original_params,modified_params)
    @original_params = original_params
    @modified_params = modified_params
    super(query,full_query_path,xml,num_per_page)
  end
  
end