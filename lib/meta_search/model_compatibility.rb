module MetaSearch
  # Just a little module to mix in so that ActionPack doesn't complain.
  module ModelCompatibility
    def self.included(base)
      base.extend ClassMethods
    end

    # Force default "Update search" text
    def persisted?
      true
    end

    def to_key
      nil
    end

    def to_param
      nil
    end

    def to_model
      self
    end

    class Name < String
      attr_reader :singular, :plural, :element, :collection, :partial_path, :human
      alias_method :cache_key, :collection

      def initialize
        super("Search")
        @singular = "search".freeze
        @plural = "searches".freeze
        @element = "search".freeze
        @human = "Search".freeze
        @collection = "meta_search/searches".freeze
        @partial_path = "#{@collection}/#{@element}".freeze
      end
    end

    module ClassMethods
      def model_name
        @_model_name ||= Name.new
      end
    end
  end
end