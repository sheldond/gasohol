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

ActiveRecord::Schema.define(:version => 20090121203338) do

  create_table "cities", :force => true do |t|
    t.string  "name"
    t.integer "state_id"
  end

  add_index "cities", ["name"], :name => "index_cities_on_name", :unique => true

  create_table "flags", :force => true do |t|
    t.string   "asset_id"
    t.text     "comments"
    t.integer  "user_id"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "invites", :force => true do |t|
    t.string   "code"
    t.integer  "available",    :default => 0
    t.integer  "used",         :default => 0
    t.datetime "last_used_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "overrides", :force => true do |t|
    t.string   "keywords"
    t.string   "location"
    t.integer  "radius"
    t.datetime "start_date"
    t.datetime "end_date"
    t.string   "sport"
    t.string   "type"
    t.string   "custom"
    t.string   "url"
  end

  add_index "overrides", ["keywords"], :name => "index_overrides_on_keywords", :unique => true

  create_table "queries", :force => true do |t|
    t.string   "keywords"
    t.string   "location"
    t.datetime "start_date"
    t.datetime "end_date"
    t.string   "sport"
    t.string   "type"
    t.string   "custom"
    t.integer  "count",               :default => 0
    t.string   "mode"
    t.integer  "user_id"
    t.datetime "created_at"
    t.string   "original_keywords"
    t.string   "original_location"
    t.integer  "total_results"
    t.integer  "start"
    t.string   "original_start_date"
    t.string   "original_end_date"
  end

  add_index "queries", ["location"], :name => "index_queries_on_location"
  add_index "queries", ["keywords"], :name => "index_queries_on_keywords"

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"
  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"

  create_table "states", :force => true do |t|
    t.string "name"
    t.string "abbreviation"
  end

  add_index "states", ["abbreviation"], :name => "index_states_on_abbreviation", :unique => true
  add_index "states", ["name"], :name => "index_states_on_name", :unique => true

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "login"
    t.string   "password"
    t.string   "email"
    t.datetime "last_login_at"
    t.string   "last_login_ip"
    t.boolean  "can_log_in",    :default => false
    t.boolean  "is_banned",     :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_admin",      :default => false
    t.integer  "invite_id"
  end

  create_table "zips", :id => false, :force => true do |t|
    t.string  "city"
    t.string  "state"
    t.string  "zip"
    t.integer "area_code"
    t.integer "fips"
    t.string  "county"
    t.string  "preferred"
    t.string  "time_zone"
    t.boolean "dst",                                         :default => false
    t.decimal "latitude",      :precision => 7, :scale => 5
    t.decimal "longitude",     :precision => 8, :scale => 5
    t.integer "msa"
    t.integer "pmsa"
    t.integer "congress_dist"
    t.integer "dma"
    t.string  "type"
    t.integer "batch"
    t.integer "status"
  end

  add_index "zips", ["zip"], :name => "index_zips_on_zip", :unique => true

end
