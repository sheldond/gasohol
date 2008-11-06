class AddAdminToUsers < ActiveRecord::Migration
  def self.up
    add_column    :users, 'is_admin', :boolean, :default => false
    rename_column :users, 'banned', 'is_banned'
  end

  def self.down
    remove_column :users, 'is_admin'
    rename_column :users, 'is_banned', 'banned'
  end
end
