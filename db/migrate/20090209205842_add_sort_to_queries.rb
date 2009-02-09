class AddSortToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, 'sort', :string
  end

  def self.down
    remove_column :queries, 'sort'
  end
end
