class CreateStates < ActiveRecord::Migration
  def self.up
    create_table :states do |t|
      t.string :name
      t.string :abbreviation
    end
    
    add_index :states, 'name', :unique => true
    add_index :states, 'abbreviation', :unique => true
    
    File.open(File.join(File.dirname(__FILE__), 'default_data/states.txt'),'r').each_line do |line|
      State.connection.insert(line)
    end.close
    
  end

  def self.down
    drop_table :states
  end
end
