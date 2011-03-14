module MetaSearch
  module Adapters
    module ActiveRecord
      module Base

        def self.extended(base)
          alias :search :meta_search unless base.method_defined? :search
        end

        def meta_search(params = {})
          Search.new(self, params)
        end

      end
    end
  end
end