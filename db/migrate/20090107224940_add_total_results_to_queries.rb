class AddTotalResultsToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, :total_results, :integer
  end

  def self.down
    remove_column :queries, :total_results
  end
end
