class AddCategoryAndUserToQueries < ActiveRecord::Migration
  def self.up
    add_column    :queries, 'category', :string
    Query.connection.execute("update queries set category = 'activities'")
  end

  def self.down
    remove_column :queries, 'category'
  end
end
