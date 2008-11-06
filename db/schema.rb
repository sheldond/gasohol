# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20080618144802) do

  create_table "users", :force => true do |t|
    t.string   "name",          :default => "'''NULL'''"
    t.string   "login",         :default => "'''NULL'''"
    t.string   "password",      :default => "'''NULL'''"
    t.string   "email",         :default => "'''NULL'''"
    t.datetime "last_login_at"
    t.string   "last_login_ip", :default => "'''NULL'''"
    t.boolean  "can_log_in",    :default => false
    t.boolean  "is_banned",     :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_admin",      :default => false
  end

  create_table "zips", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
