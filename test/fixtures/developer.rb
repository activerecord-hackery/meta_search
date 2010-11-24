class Developer < ActiveRecord::Base
  belongs_to :company
  has_and_belongs_to_many :projects
  has_many :notes, :as => :notable

  attr_searchable :name, :salary, :if => proc {|s| !s.options[:user] || s.options[:user] == 'privileged'}
  assoc_searchable :notes, :projects, :company, :if => proc {|s| !s.options[:user] || s.options[:user] == 'privileged'}

  scope :sort_by_salary_and_name_asc, order('salary ASC, name ASC')
  scope :sort_by_salary_and_name_desc, order('salary DESC, name DESC')
end