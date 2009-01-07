class AddOriginalKeywordAndLocationToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, :original_keywords, :string
    add_column :queries, :original_location, :string
  end

  def self.down
    remove_column :queries, :original_keywords
    remove_column :queries, :original_location
  end
end
