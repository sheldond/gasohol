class AddRadiusToQueries < ActiveRecord::Migration
  def self.up
    add_column :queries, 'radius', :integer
    
    # update all existing searches with the default 50 mile radius
    Query.connection.execute("update queries set radius = 50 where mode = 'activities' or mode = 'orgs' or mode = 'facilities'")
  end

  def self.down
    remove_column :queries, 'radius'
  end
end
