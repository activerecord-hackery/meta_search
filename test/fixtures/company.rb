class Company < ActiveRecord::Base
  has_many :developers
  has_many :developer_notes, :through => :developers, :source => :notes
  has_many :slackers, :class_name => "Developer", :conditions => {:slacker => true}
  has_many :notes, :as => :notable
  has_many :data_types
end