class AddCategoryAndUserToQueries < ActiveRecord::Migration
  def self.up
    add_column    :queries, 'user_id', :integer, :default => 0
    add_column    :queries, 'category', :string
    
    Query.connection.execute("update queries set category = 'activities'")
  end

  def self.down
    remove_column :queries, 'user_id'
    remove_column :queries, 'category'
  end
end
