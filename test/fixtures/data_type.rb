class DataType < ActiveRecord::Base
  belongs_to :company
  attr_unsearchable :str
  attr_protected :str
end