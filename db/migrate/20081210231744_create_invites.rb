class CreateInvites < ActiveRecord::Migration
  def self.up
    create_table :invites do |t|
      t.string :code
      t.integer :available, :default => 0
      t.integer :used, :default => 0
      t.datetime :last_used_at

      t.timestamps
    end
  end

  def self.down
    drop_table :invites
  end
end
