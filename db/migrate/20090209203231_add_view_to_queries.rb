class AddViewToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, 'view', :string
  end

  def self.down
    remove_column :queries, 'view'
  end
end
