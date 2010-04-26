class Company < ActiveRecord::Base
  has_many :developers
  has_many :developer_notes, :through => :developers, :source => :notes
  has_many :slackers, :class_name => "Developer", :conditions => {:slacker => true}
  has_many :notes, :as => :notable
  has_many :data_types
  
  scope :backwards_name, lambda {|name| where(:name => name.reverse)}
  search_methods :backwards_name
  search_methods :developer_count_between, :splat_param => true
  non_searchable_attributes :updated_at
  non_searchable_associations :notes
end