require 'polyamorous'
require 'meta_search/model_compatibility'
require 'meta_search/exceptions'
require 'meta_search/where'
require 'meta_search/utility'

module MetaSearch
  # Builder is the workhorse of MetaSearch -- it is the class that handles dynamically generating
  # methods based on a supplied model, and is what gets instantiated when you call your model's search
  # method. Builder doesn't generate any methods until they're needed, using method_missing to compare
  # requested method names against your model's attributes, associations, and the configured Where
  # list.
  #
  # === Attributes
  #
  # * +base+ - The base model that Builder wraps.
  # * +search_attributes+ - Attributes that have been assigned (search terms)
  # * +relation+ - The ActiveRecord::Relation representing the current search.
  # * +join_dependency+ - The JoinDependency object representing current association join
  #   dependencies. It's used internally to avoid joining association tables more than
  #   once when constructing search queries.
  class Builder
    include ModelCompatibility
    include Utility

    attr_reader :base, :relation, :search_key, :search_attributes, :join_dependency, :errors, :options
    delegate *RELATION_METHODS + [:to => :relation]

    # Initialize a new Builder. Requires a base model to wrap, and supports a couple of options
    # for how it will expose this model and its associations to your controllers/views.
    def initialize(base_or_relation, opts = {})
      opts = opts.dup
      @relation = base_or_relation.scoped
      @base = @relation.klass
      @search_key = (opts.delete(:search_key) || 'search').to_s
      @options = opts  # Let's just hang on to other options for use in authorization blocks
      @join_type = opts[:join_type] ||  Arel::Nodes::OuterJoin
      @join_type = get_join_type(@join_type)
      @join_dependency = build_join_dependency(@relation)
      @search_attributes = {}
      @errors = ActiveModel::Errors.new(self)
    end

    def get_column(column, base = @base)
      base.columns_hash[column.to_s] if base._metasearch_attribute_authorized?(column, self)
    end

    def get_association(assoc, base = @base)
      base.reflect_on_association(assoc.to_sym) if base._metasearch_association_authorized?(assoc, self)
    end

    def get_attribute(name, parent = @join_dependency.join_base)
      attribute = nil
      if get_column(name, parent.active_record)
        attribute = parent.table[name]
      elsif (segments = name.to_s.split(/_/)).size > 1
        remainder = []
        found_assoc = nil
        while remainder.unshift(segments.pop) && segments.size > 0 && !found_assoc do
          if found_assoc = get_association(segments.join('_'), parent.active_record)
            if found_assoc.options[:polymorphic]
              unless delimiter = remainder.index('type')
                raise PolymorphicAssociationMissingTypeError, "Polymorphic association specified without a type"
              end
              polymorphic_class, attribute_name = remainder[0...delimiter].join('_'),
                                                  remainder[delimiter + 1...remainder.size].join('_')
              polymorphic_class = polymorphic_class.classify.constantize
              join = build_or_find_association(found_assoc.name, parent, polymorphic_class)
              attribute = get_attribute(attribute_name, join)
            else
              join = build_or_find_association(found_assoc.name, parent, found_assoc.klass)
              attribute = get_attribute(remainder.join('_'), join)
            end
          end
        end
      end
      attribute
    end

    # Build the search with the given search options. Options are in the form of a hash
    # with keys matching the names creted by the Builder's "wheres" as outlined in
    # MetaSearch::Where
    def build(option_hash)
      opts = option_hash.dup || {}
      @relation = @base.scoped
      opts.stringify_keys!
      opts = collapse_multiparameter_options(opts)
      assign_attributes(opts)
      self
    end

    def respond_to?(method_id, include_private = false)
      return true if super

      method_name = method_id.to_s
      if RELATION_METHODS.map(&:to_s).include?(method_name)
        true
      elsif method_name.match(/^meta_sort=?$/)
        true
      elsif match = method_name.match(/^(.*)\(([0-9]+).*\)$/)
        method_name, index = match.captures
        respond_to?(method_name)
      elsif matches_named_method(method_name) || matches_attribute_method(method_name)
        true
      else
        false
      end
    end

    private

    def assign_attributes(opts)
      opts.each_pair do |k, v|
        self.send("#{k}=", v)
      end
    end

    def gauge_depth_of_join_association(ja)
      1 + (ja.respond_to?(:parent) ? gauge_depth_of_join_association(ja.parent) : 0)
    end

    def method_missing(method_id, *args, &block)
      method_name = method_id.to_s
      if method_name =~ /^meta_sort=?$/
        (args.any? || method_name =~ /=$/) ? set_sort(args.first) : get_sort
      elsif match = method_name.match(/^(.*)\(([0-9]+).*\)$/) # Multiparameter reader
        method_name, index = match.captures
        vals = self.send(method_name)
        vals.is_a?(Array) ? vals[index.to_i - 1] : nil
      elsif match = matches_named_method(method_name)
        (args.any? || method_name =~ /=$/) ? set_named_method_value(match, args.first) : get_named_method_value(match)
      elsif match = matches_attribute_method(method_id)
        attribute, predicate = match.captures
         (args.any? || method_name =~ /=$/) ? set_attribute_method_value(attribute, predicate, args.first) : get_attribute_method_value(attribute, predicate)
      else
        super
      end
    end

    def matches_named_method(name)
      method_name = name.to_s.sub(/\=$/, '')
      return method_name if @base._metasearch_method_authorized?(method_name, self)
    end

    def matches_attribute_method(method_id)
      method_name = preferred_method_name(method_id)
      where = Where.new(method_id) rescue nil
      return nil unless method_name && where
      match = method_name.match("^(.*)_(#{where.name})=?$")
      attribute, predicate = match.captures
      attributes = attribute.split(/_or_/)
      if attributes.all? {|a| where.types.include?(column_type(a))}
        return match
      end
      nil
    end

    def get_sort
      search_attributes['meta_sort']
    end

    def set_sort(val)
      return if val.blank?
      column, direction = val.split('.')
      direction ||= 'asc'
      if ['asc','desc'].include?(direction)
        if @base.respond_to?("sort_by_#{column}_#{direction}")
          search_attributes['meta_sort'] = val
          @relation = @relation.send("sort_by_#{column}_#{direction}")
        elsif attribute = get_attribute(column)
          search_attributes['meta_sort'] = val
          @relation = @relation.order(attribute.send(direction).to_sql)
        elsif column.scan('_and_').present?
          attribute_names = column.split('_and_')
          attributes = attribute_names.map {|n| get_attribute(n)}
          if attribute_names.size == attributes.compact.size # We found all attributes
            search_attributes['meta_sort'] = val
            attributes.each do |attribute|
              @relation = @relation.order(attribute.send(direction).to_sql)
            end
          end
        end
      end
    end

    def get_named_method_value(name)
      search_attributes[name]
    end

    def set_named_method_value(name, val)
      meth = @base._metasearch_methods[name][:method]
      search_attributes[name] = meth.cast_param(val)
      if meth.validate(search_attributes[name])
        return_value = meth.evaluate(@relation, search_attributes[name])
        if return_value.is_a?(ActiveRecord::Relation)
          @relation = return_value
        else
          raise NonRelationReturnedError, "Custom search methods must return an ActiveRecord::Relation. #{name} returned a #{return_value.class}"
        end
      end
    end

    def get_attribute_method_value(attribute, predicate)
      search_attributes["#{attribute}_#{predicate}"]
    end

    def set_attribute_method_value(attribute, predicate, val)
      where = Where.new(predicate)
      attributes = attribute.split(/_or_/)
      search_attributes["#{attribute}_#{predicate}"] = cast_attributes(where.cast || column_type(attributes.first), val)
      if where.validate(search_attributes["#{attribute}_#{predicate}"])
        arel_attributes = attributes.map {|a| get_attribute(a)}
        @relation = where.evaluate(@relation, arel_attributes, search_attributes["#{attribute}_#{predicate}"])
      end
    end

    def column_type(name, base = @base, depth = 1)
      type = nil
      if column = get_column(name, base)
        type = column.type
      elsif (segments = name.split(/_/)).size > 1
        type = type_from_association_segments(segments, base, depth)
      end
      type
    end

    def type_from_association_segments(segments, base, depth)
      remainder = []
      found_assoc = nil
      type = nil
      while remainder.unshift(segments.pop) && segments.size > 0 && !found_assoc do
        if found_assoc = get_association(segments.join('_'), base)
          depth += 1
          raise JoinDepthError, "Maximum join depth of #{MAX_JOIN_DEPTH} exceeded." if depth > MAX_JOIN_DEPTH
          if found_assoc.options[:polymorphic]
            unless delimiter = remainder.index('type')
              raise PolymorphicAssociationMissingTypeError, "Polymorphic association specified without a type"
            end
            polymorphic_class, attribute_name = remainder[0...delimiter].join('_'),
                                                remainder[delimiter + 1...remainder.size].join('_')
            polymorphic_class = polymorphic_class.classify.constantize
            type = column_type(attribute_name, polymorphic_class, depth)
          else
            type = column_type(remainder.join('_'), found_assoc.klass, depth)
          end
        end
      end
      type
    end

    def build_or_find_association(name, parent = @join_dependency.join_base, klass = nil)
      found_association = @join_dependency.join_associations.detect do |assoc|
        assoc.reflection.name == name &&
        assoc.parent == parent &&
        (!klass || assoc.reflection.klass == klass)
      end
      unless found_association
        @join_dependency.send(:build, Polyamorous::Join.new(name, @join_type, klass), parent)
        found_association = @join_dependency.join_associations.last
        # Leverage the stashed association functionality in AR
        @relation = @relation.joins(found_association)
      end

      found_association
    end

    def build_join_dependency(relation)
      buckets = relation.joins_values.group_by do |join|
        case join
        when String
          'string_join'
        when Hash, Symbol, Array
          'association_join'
        when ::ActiveRecord::Associations::JoinDependency::JoinAssociation
          'stashed_join'
        when Arel::Nodes::Join
          'join_node'
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      association_joins         = buckets['association_join'] || []
      stashed_association_joins = buckets['stashed_join'] || []
      join_nodes                = buckets['join_node'] || []
      string_joins              = (buckets['string_join'] || []).map { |x|
        x.strip
      }.uniq

      join_list = relation.send :custom_join_ast, relation.table.from(relation.table), string_joins

      join_dependency = ::ActiveRecord::Associations::JoinDependency.new(
        relation.klass,
        association_joins,
        join_list
      )

      join_nodes.each do |join|
        join_dependency.alias_tracker.aliased_name_for(join.left.name.downcase)
      end

      join_dependency.graft(*stashed_association_joins)
    end

    def get_join_type(opt_join)
      # Allow "inner"/:inner and "upper"/:upper
      if opt_join.to_s.upcase == 'INNER'
        opt_join = Arel::Nodes::InnerJoin
      elsif opt_join.to_s.upcase == 'OUTER'
        opt_join = Arel::Nodes::OuterJoin
      end
      # Default to trusting what the user gave us
      opt_join
    end
  end
end
