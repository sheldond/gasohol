class CreateFlags < ActiveRecord::Migration
  def self.up
    create_table :flags do |t|
      t.string :asset_id
      t.text :comments
      t.integer :user_id
      t.string :status

      t.timestamps
    end
  end

  def self.down
    drop_table :flags
  end
end
