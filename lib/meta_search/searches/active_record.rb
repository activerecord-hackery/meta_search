require 'meta_search/searches/base'
require 'active_record'

module MetaSearch::Searches
  module ActiveRecord
    include MetaSearch::Searches::Base
    
    # Mixes MetaSearch into ActiveRecord::Base.
    def self.enable!
      ::ActiveRecord::Base.class_eval do
        class_attribute :_metasearch_exclude_attributes
        class_attribute :_metasearch_exclude_associations
        self._metasearch_exclude_attributes = []
        self._metasearch_exclude_associations = []
        extend ActiveRecord
      end
    end
  end
end