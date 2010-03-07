require 'meta_search/searches/base'
require 'active_record'

module MetaSearch::Searches
  module ActiveRecord
    include MetaSearch::Searches::Base
    
    # Mixes MetaSearch into ActiveRecord::Base.
    def self.enable!
      ::ActiveRecord::Base.class_eval do
        extend ActiveRecord
      end
    end
  end
end