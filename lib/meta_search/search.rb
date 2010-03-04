module MetaSearch
  module Search
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def search(opts = {})
        builder = MetaSearch::Builder.new(self)
        builder.build(opts)
      end
      
      def meta_search_where(*args)
      end
    end
  end
end