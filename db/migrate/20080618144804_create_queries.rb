class CreateQueries < ActiveRecord::Migration
  def self.up
    create_table :queries do |t|
      t.string :keywords
      t.string :location
      t.datetime :start_date
      t.datetime :end_date
      t.string :sport
      t.string :type
      t.string :custom
      t.integer :count, :default => 0
    end
  end

  def self.down
    drop_table :queries
  end
end
