class Developer < ActiveRecord::Base
  belongs_to :company
  has_and_belongs_to_many :projects
  has_many :notes, :as => :notable
  
  attr_searchable :name, :salary
  assoc_searchable :notes, :projects, :company
end