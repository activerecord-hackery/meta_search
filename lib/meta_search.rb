require 'active_record'
require 'meta_search/builder'
require 'meta_search/search'

module MetaSearch
  class << self
    def add_search_to_active_record
      return if ActiveRecord::Base.respond_to? :search
      ActiveRecord::Base.send :include, Search
    end
  end
end

if defined? Rails
  MetaSearch.add_search_to_active_record
end