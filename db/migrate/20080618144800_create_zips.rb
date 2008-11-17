class CreateZips < ActiveRecord::Migration
  def self.up
    create_table :zips, :id => false do |t|
      t.column 'city', :string
      t.column 'state', :string
      t.column 'zip', :integer
      t.column 'area_code', :integer
      t.column 'fips', :integer
      t.column 'county', :string
      t.column 'preferred', :string
      t.column 'time_zone', :string
      t.column 'dst', :boolean, :default => false
      t.column 'latitude', :decimal, :precision => 7, :scale => 5
      t.column 'longitude', :decimal, :precision => 7, :scale => 5
      t.column 'msa', :integer
      t.column 'pmsa', :integer
      t.column 'congress_dist', :integer
      t.column 'dma', :integer
      t.column 'type', :string
      t.column 'batch', :integer
      t.column 'status', :integer
    end
    
    add_index :zips, 'zip', :unique => true
    
    File.open(File.join(File.dirname(__FILE__), 'default_data/inserts.txt'),'r').each_line do |line|
      Zip.connection.insert(line)
      # print 'inserted...'
    end.close
    
    puts '  -- done insert.'
    
  end

  def self.down
    drop_table :zips
  end
end
