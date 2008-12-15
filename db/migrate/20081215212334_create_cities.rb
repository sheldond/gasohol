class CreateCities < ActiveRecord::Migration
  def self.up
    create_table :cities do |t|
      t.string :name
      t.integer :state_id
    end
    
    add_index :cities, 'name', :unique => true
    
    File.open(File.join(File.dirname(__FILE__), 'default_data/cities.txt'),'r').each_line do |line|
      City.connection.insert(line)
    end.close
    
  end

  def self.down
    drop_table :cities
  end
end
