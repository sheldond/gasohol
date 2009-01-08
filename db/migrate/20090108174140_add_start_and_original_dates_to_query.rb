class AddStartAndOriginalDatesToQuery < ActiveRecord::Migration
  def self.up
    add_column :queries, :start, :integer
    add_column :queries, :original_start_date, :string
    add_column :queries, :original_end_date, :string
  end

  def self.down
    remove_column :queries, :start
    remove_column :queries, :original_start_date
    remove_column :queries, :original_end_date
  end
end
