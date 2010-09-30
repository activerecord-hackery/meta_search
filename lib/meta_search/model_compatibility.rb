module MetaSearch

  module ModelCompatibility
    def persisted?
      false
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

    def model_name
      @_model_name ||= Name.new(self.base)
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
      @route_key = base.model_name.route_key
    end
  end

end