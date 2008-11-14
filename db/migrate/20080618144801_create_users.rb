class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string    :name
      t.string    :login
      t.string    :password
      t.string    :email
      t.datetime  :last_login_at
      t.string    :last_login_ip
      t.boolean   :can_log_in, :default => false
      t.boolean   :banned, :default => false
      
      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end