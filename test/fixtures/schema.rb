ActiveRecord::Schema.define do

  create_table "companies", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  
  create_table "developers", :force => true do |t|
    t.integer  "company_id"
    t.string   "name"
    t.integer  "salary"
    t.boolean  "slacker"
  end
  
  create_table "projects", :force => true do |t|
    t.string   "name"
    t.float    "estimated_hours"
  end
  
  create_table "developers_projects", :id => false, :force => true do |t|
    t.integer  "developer_id"
    t.integer  "project_id"
  end
  
  create_table "notes", :force => true do |t|
    t.string   "notable_type"
    t.integer  "notable_id"
    t.string   "note"
  end

  create_table "data_types", :force => true do |t|
    t.integer  "company_id"
    t.string   "str"
    t.text     "txt"
    t.integer  "int"
    t.float    "flt"
    t.decimal  "dec"
    t.datetime "dtm"
    t.timestamp "tms"
    t.time     "tim"
    t.date     "dat"
    t.binary   "bin"
    t.boolean  "bln"
  end

end