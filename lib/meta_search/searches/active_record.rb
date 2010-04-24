require 'active_support/concern'
require 'meta_search/searches/base'

module MetaSearch::Searches
  module ActiveRecord
    extend ActiveSupport::Concern
    
    included do
      extend MetaSearch::Searches::Base
      class_attribute :_metasearch_exclude_attributes
      class_attribute :_metasearch_exclude_associations
      self._metasearch_exclude_attributes = []
      self._metasearch_exclude_associations = []
    end
  end
end