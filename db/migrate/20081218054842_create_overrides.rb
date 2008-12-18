class CreateOverrides < ActiveRecord::Migration
  def self.up
    create_table :overrides do |t|
      t.string :keywords
      t.string :location
      t.integer :radius
      t.datetime :start_date
      t.datetime :end_date
      t.string :sport
      t.string :type
      t.string :custom
      t.string :url
    end
    
    add_index :overrides, 'keywords', :unique => true
    
    File.open(File.join(File.dirname(__FILE__), 'default_data/overrides.txt'),'r').each_line do |line|
      Override.connection.insert(line)
    end.close
    
  end

  def self.down
    drop_table :overrides
  end
end
