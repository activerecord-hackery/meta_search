class Company < ActiveRecord::Base
  has_many :developers
  has_many :developer_notes, :through => :developers, :source => :notes
  has_many :slackers, :class_name => "Developer", :conditions => {:slacker => true}
  has_many :notes, :as => :notable
  has_many :data_types

  scope :backwards_name, lambda {|name| where(:name => name.reverse)}
  scope :with_slackers_by_name_and_salary_range,
    lambda {|name, low, high|
      joins(:slackers).where(:developers => {:name => name, :salary => low..high})
    }
  search_methods :backwards_name, :backwards_name_as_string, :if => proc {|s| s.options[:user] != 'blocked'}
  search_methods :with_slackers_by_name_and_salary_range,
    :splat_param => true, :type => [:string, :integer, :integer]
  attr_unsearchable :updated_at, :if => proc {|s| s.options[:user] == 'blocked' || !s.options[:user]}
  assoc_unsearchable :notes, :if => proc {|s| s.options[:user] == 'blocked' || !s.options[:user]}

  def self.backwards_name_as_string(name)
    name.reverse
  end
end