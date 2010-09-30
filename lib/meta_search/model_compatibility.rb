module MetaSearch
  # Just a little module to mix in so that ActionPack doesn't complain.
  module ModelCompatibility

    def to_model
      @_compatible_model = CompatibleModel.new(base)
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

    class Name < String
      attr_reader :singular, :plural, :element, :collection, :partial_path, :human, :param_key, :route_key
      alias_method :cache_key, :collection

      def initialize(base)
        super("Search")
        @singular = "search".freeze
        @plural = "searches".freeze
        @element = "search".freeze
        @human = "Search".freeze
        @collection = "meta_search/searches".freeze
        @partial_path = "#{@collection}/#{@element}".freeze
        @param_key = "search".freeze
        @route_key = base.route_key
      end
    end

  end
end