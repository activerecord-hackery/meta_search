class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers
  has_many :notes, :as => :notable
end