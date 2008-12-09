# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20081205204633) do

  create_table "queries", :force => true do |t|
    t.string   "keywords"
    t.string   "location"
    t.datetime "start_date"
    t.datetime "end_date"
    t.string   "sport"
    t.string   "type"
    t.string   "custom"
    t.integer  "count",      :default => 0
  end

  add_index "queries", ["location"], :name => "index_queries_on_location"
  add_index "queries", ["keywords"], :name => "index_queries_on_keywords"

  create_table "sessions", :force => true do |t|
    t.string   "session_id",                     :null => false
    t.text     "data",       :default => "NULL"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"
  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"

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

  create_table "zips", :id => false, :force => true do |t|
    t.string  "city",                                        :default => "NULL"
    t.string  "state",                                       :default => "NULL"
    t.integer "zip",                                         :default => 0
    t.integer "area_code",                                   :default => 0
    t.integer "fips",                                        :default => 0
    t.string  "county",                                      :default => "NULL"
    t.string  "preferred",                                   :default => "NULL"
    t.string  "time_zone",                                   :default => "NULL"
    t.boolean "dst",                                         :default => false
    t.decimal "latitude",      :precision => 7, :scale => 5, :default => 0.0
    t.decimal "longitude",     :precision => 7, :scale => 5, :default => 0.0
    t.integer "msa",                                         :default => 0
    t.integer "pmsa",                                        :default => 0
    t.integer "congress_dist",                               :default => 0
    t.integer "dma",                                         :default => 0
    t.string  "type",                                        :default => "NULL"
    t.integer "batch",                                       :default => 0
    t.integer "status",                                      :default => 0
  end

  add_index "zips", ["zip"], :name => "index_zips_on_zip", :unique => true

end
