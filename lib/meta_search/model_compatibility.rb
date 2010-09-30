module MetaSearch

  module ModelCompatibility

    def self.included(base)
      base.extend ClassMethods
    end

    def persisted?
      false
    end

    class CompatibleModel
      attr_reader :base

      def initialize(base)
        @base = base
      end

      def class
        @base
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
    end
  end

  class Name < String
    attr_reader :singular, :plural, :element, :collection, :partial_path, :human, :param_key, :route_key
    alias_method :cache_key, :collection

    def initialize
      super("Search")
      @singular = "search".freeze
      @plural = "searches".freeze
      @element = "search".freeze
      @human = "Search".freeze
      @collection = "meta_search/searches".freeze
      @partial_path = "#{@collection}/#{@element}".freeze
      @param_key = "search".freeze
      @route_key = "searches".freeze
    end
  end

  module ClassMethods
    def model_name
      @_model_name ||= Name.new
    end
  end

end