require 'meta_search/model_compatibility'
require 'meta_search/exceptions'
require 'meta_search/where'
require 'meta_search/utility'

module MetaSearch
  # Raised if you try to access a relation that's joining too many tables to itself.
  # This is designed to prevent a malicious user from accessing something like
  # :developers_company_developers_company_developers_company_developers_company_...,
  # resulting in a query that could cause issues for your database server.
  class JoinDepthError < StandardError; end

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

    attr_reader :base, :search_attributes, :join_dependency
    delegate *RELATION_METHODS + [:to => :relation]

    # Initialize a new Builder. Requires a base model to wrap, and supports a couple of options
    # for how it will expose this model and its associations to your controllers/views.
    def initialize(base_or_relation, opts = {})
      @relation = base_or_relation.scoped
      @base = @relation.klass
      @opts = opts
      @join_dependency = build_join_dependency
      @search_attributes = {}
    end

    def relation
      enforce_join_depth_limit!
      @relation
    end

    def get_column(column, base = @base)
      if base._metasearch_include_attributes.blank?
        base.columns_hash[column.to_s] unless base._metasearch_exclude_attributes.include?(column.to_s)
      else
        base.columns_hash[column.to_s] if base._metasearch_include_attributes.include?(column.to_s)
      end
    end

    def get_association(assoc, base = @base)
      if base._metasearch_include_associations.blank?
        base.reflect_on_association(assoc.to_sym) unless base._metasearch_exclude_associations.include?(assoc.to_s)
      else
        base.reflect_on_association(assoc.to_sym) if base._metasearch_include_associations.include?(assoc.to_s)
      end
    end

    def get_attribute(name, parent = @join_dependency.join_base)
      attribute = nil
      if get_column(name, parent.active_record)
        if parent.is_a?(ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)
          relation = parent.relation.is_a?(Array) ? parent.relation.last : parent.relation
          attribute = relation.table[name]
        else
          attribute = @relation.table[name]
        end
      elsif (segments = name.to_s.split(/_/)).size > 1
        remainder = []
        found_assoc = nil
        while remainder.unshift(segments.pop) && segments.size > 0 && !found_assoc do
          if found_assoc = get_association(segments.join('_'), parent.active_record)
            join = build_or_find_association(found_assoc.name, parent)
            attribute = get_attribute(remainder.join('_'), join)
          end
        end
      end
      attribute
    end

    def base_includes_association?(base, assoc)
      if base._metasearch_include_associations.blank?
        base.reflect_on_association(assoc.to_sym) unless base._metasearch_exclude_associations.include?(assoc.to_s)
      else
        base.reflect_on_association(assoc.to_sym) if base._metasearch_include_associations.include?(assoc.to_s)
      end
    end

    def base_includes_attribute?(base, attribute)
      if base._metasearch_include_attributes.blank?
        base.column_names.detect(attribute.to_s) unless base._metasearch_exclude_attributes.include?(attribute.to_s)
      else
        base.column_names.detect(attribute.to_s) if base._metasearch_include_attributes.include?(attribute.to_s)
      end
    end

    # Build the search with the given search options. Options are in the form of a hash
    # with keys matching the names creted by the Builder's "wheres" as outlined in
    # MetaSearch::Where
    def build(opts)
      opts ||= {}
      @relation = @base.scoped
      opts.stringify_keys!
      opts = collapse_multiparameter_options(opts)
      assign_attributes(opts)
      self
    end

    private

    def method_missing(method_id, *args, &block)
      if method_id.to_s =~ /^meta_sort=?$/
        build_sort_method
        self.send(method_id, *args)
      elsif match = method_id.to_s.match(/^(.*)\(([0-9]+).*\)$/) # Multiparameter reader
        method_name, index = match.captures
        vals = self.send(method_name)
        vals.is_a?(Array) ? vals[index.to_i - 1] : nil
      elsif match = matches_named_method(method_id)
        build_named_method(match)
        self.send(method_id, *args)
      elsif match = matches_attribute_method(method_id)
        attribute, predicate = match.captures
        build_attribute_method(attribute, predicate)
        self.send(preferred_method_name(method_id), *args)
      else
        super
      end
    end

    def build_join_dependency
      joins = @relation.joins_values.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

      association_joins = joins.select do |j|
        [Hash, Array, Symbol].include?(j.class) && !array_of_strings?(j)
      end

      stashed_association_joins = joins.select do |j|
        j.is_a?(ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)
      end

      non_association_joins = (joins - association_joins - stashed_association_joins)
      custom_joins = custom_join_sql(*non_association_joins)

      ActiveRecord::Associations::ClassMethods::JoinDependency.new(@base, association_joins, custom_joins)
    end

    def custom_join_sql(*joins)
      arel = @relation.table
      joins.each do |join|
        next if join.blank?

        case join
        when Hash, Array, Symbol
          if array_of_strings?(join)
            join_string = join.join(' ')
            arel = arel.join(join_string)
          end
        else
          arel = arel.join(join)
        end
      end
      arel.joins(arel)
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

    def build_sort_method
      singleton_class.instance_eval do
        define_method(:meta_sort) do
          search_attributes['meta_sort']
        end

        define_method(:meta_sort=) do |val|
          column, direction = val.split('.')
          direction ||= 'asc'
          if ['asc','desc'].include?(direction) && attribute = get_attribute(column)
            search_attributes['meta_sort'] = val
            @relation = @relation.order(attribute.send(direction).to_sql)
          end
        end
      end
    end

    def column_type(name, base = @base)
      type = nil
      if column = get_column(name, base)
        type = column.type
      elsif (segments = name.split(/_/)).size > 1
        remainder = []
        found_assoc = nil
        while remainder.unshift(segments.pop) && segments.size > 0 && !found_assoc do
          if found_assoc = get_association(segments.join('_'), base)
            type = column_type(remainder.join('_'), found_assoc.klass)
          end
        end
      end
      type
    end

    def build_named_method(name)
      meth = @base._metasearch_methods[name]
      singleton_class.instance_eval do
        define_method(name) do
          search_attributes[name]
        end

        define_method("#{name}=") do |val|
          search_attributes[name] = meth.cast_param(val)
          if meth.validate(search_attributes[name])
            return_value = meth.eval(@relation, search_attributes[name])
            if return_value.is_a?(ActiveRecord::Relation)
              @relation = return_value
            else
              raise NonRelationReturnedError, "Custom search methods must return an ActiveRecord::Relation. #{name} returned a #{return_value.class}"
            end
          end
        end
      end
    end

    def build_attribute_method(attribute, predicate)
      singleton_class.instance_eval do
        define_method("#{attribute}_#{predicate}") do
          search_attributes["#{attribute}_#{predicate}"]
        end

        define_method("#{attribute}_#{predicate}=") do |val|
          where = Where.new(predicate)
          search_attributes["#{attribute}_#{predicate}"] = cast_attributes(where.cast || column_type(attribute), val)
          if where.validate(search_attributes["#{attribute}_#{predicate}"])
            arel_attribute = get_attribute(attribute)
            @relation = where.eval(@relation, arel_attribute, search_attributes["#{attribute}_#{predicate}"])
          end
        end
      end
    end

    def build_or_find_association(association, parent = @join_dependency.join_base)
      found_association = @join_dependency.join_associations.detect do |assoc|
        assoc.reflection.name == association.to_sym &&
        assoc.parent == parent
      end
      unless found_association
        @join_dependency.send(:build, association, parent)
        found_association = @join_dependency.join_associations.last
        @relation = @relation.joins(found_association)
      end
      found_association
    end

    def enforce_join_depth_limit!
      raise JoinDepthError, "Maximum join depth of #{MAX_JOIN_DEPTH} exceeded." if @join_dependency.join_associations.detect {|ja|
        gauge_depth_of_join_association(ja) > MAX_JOIN_DEPTH
      }
    end

    def gauge_depth_of_join_association(ja)
      1 + (ja.respond_to?(:parent) ? gauge_depth_of_join_association(ja.parent) : 0)
    end

    def matches_named_method(name)
      method_name = name.to_s.sub(/\=$/, '')
      return method_name if @base._metasearch_methods.has_key?(method_name)
    end

    def matches_attribute_method(method_id)
      method_name = preferred_method_name(method_id)
      where = Where.new(method_id) rescue nil
      return nil unless method_name && where
      match = method_name.match("^(.*)_(#{where.name})=?$")
      attribute, predicate = match.captures
      if where.types.include?(column_type(attribute))
        return match
      end
      nil
    end

    def matches_association_method(method_id)
      method_name = preferred_method_name(method_id)
      where = Where.new(method_id) rescue nil
      return nil unless method_name && where
      match = method_name.match("^(.*)_(#{where.name})=?$")
      attribute, predicate = match.captures
      self.included_associations.each do |association|
        test_attribute = attribute.dup
        if test_attribute.gsub!(/^#{association}_/, '') &&
          match = method_name.match("^(#{association})_(#{test_attribute})_(#{predicate})=?$")
          return match if where.types.include?(association_type_for(association, test_attribute))
        end
      end
      nil
    end

    def preferred_method_name(method_id)
      method_name = method_id.to_s
      where = Where.new(method_name) rescue nil
      return nil unless where
      where.aliases.each do |a|
        break if method_name.sub!(/#{a}(=?)$/, "#{where.name}\\1")
      end
      method_name
    end

    def assign_attributes(opts)
      opts.each_pair do |k, v|
        self.send("#{k}=", v)
      end
    end

    def type_for(attribute)
      column = self.column(attribute)
      column.type if column
    end

    def class_for(attribute)
      column = self.column(attribute)
      column.klass if column
    end

    def association_type_for(association, attribute)
      column = self.association_column(association, attribute)
      column.type if column
    end

    def association_class_for(association, attribute)
      column = self.association_column(association, attribute)
      column.klass if column
    end
  end
end