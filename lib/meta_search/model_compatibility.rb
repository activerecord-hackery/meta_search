require 'meta_search/utility'

module MetaSearch

  module ModelCompatibility

    def self.included(base)
      base.extend ClassMethods
    end

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
  end

  class Name < String
    attr_reader :singular, :plural, :element, :collection, :partial_path, :human, :param_key, :route_key, :i18n_key
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
      @i18n_key = :meta_search
    end
  end

  module ClassMethods
    include Utility

    def model_name
      @_model_name ||= Name.new
    end

    def human_attribute_name(attribute, options = {})
      method_name = preferred_method_name(attribute)

      defaults = [:"meta_search.attributes.#{klass.model_name.i18n_key}.#{method_name || attribute}"]

      if method_name
        predicate = Where.get(method_name)[:name]
        predicate_attribute = method_name.sub(/_#{predicate}=?$/, '')
        predicate_attributes = predicate_attribute.split(/_or_/).map { |att|
          klass.human_attribute_name(att)
        }.join(" #{I18n.translate(:"meta_search.or", :default => 'or')} ")
        defaults << :"meta_search.predicates.#{predicate}"
      end

      defaults << options.delete(:default) if options[:default]
      defaults << attribute.to_s.humanize

      options.reverse_merge! :count => 1, :default => defaults, :attribute => predicate_attributes || klass.human_attribute_name(attribute)
      I18n.translate(defaults.shift, options)
    end
  end

end