class RenameCategoryColumnInQueries < ActiveRecord::Migration
  def self.up
    rename_column :queries, 'category', 'mode'
  end

  def self.down
    rename_column :queries, 'mode', 'category'
  end
end
