class DataType < ActiveRecord::Base
  belongs_to :company
  metasearch_exclude_attr :str
end