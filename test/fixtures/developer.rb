class Developer < ActiveRecord::Base
  belongs_to :company
  has_and_belongs_to_many :projects
  has_many :notes, :as => :notable
  
  searchable_attributes :name, :salary
  searchable_associations :notes, :projects
end