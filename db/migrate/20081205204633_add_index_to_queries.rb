class AddIndexToQueries < ActiveRecord::Migration
  def self.up
    
    add_index :queries, 'keywords'
    add_index :queries, 'location'
    
  end

  def self.down
  end
end
