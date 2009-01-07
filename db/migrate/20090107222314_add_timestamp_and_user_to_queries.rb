class AddTimestampAndUserToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, 'user_id', :integer
    add_column :queries, 'created_at', :datetime
    Query.connection.execute('update queries set user_id = 1')
  end

  def self.down
    remove_column :queries, 'user_id'
    remove_column :queries, 'created_at'
  end
end
