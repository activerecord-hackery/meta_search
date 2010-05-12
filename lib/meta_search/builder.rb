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
    
    attr_reader :base, :search_attributes, :relation, :join_dependency
    delegate *RELATION_METHODS + [:to => :relation]

    # Initialize a new Builder. Requires a base model to wrap, and supports a couple of options
    # for how it will expose this model and its associations to your controllers/views.
    def initialize(base, opts = {})
      @base = base
      @opts = opts
      @associations = {}
      @join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@base, [], nil)
      @search_attributes = {}
      @relation = @base.scoped
    end
    
    # Return the column info for the given model attribute (if not excluded as outlined above)
    def column(attr)
      @base.columns_hash[attr.to_s] if self.includes_attribute?(attr)
    end
    
    # Return the association reflection for the named association (if not excluded as outlined
    # above)
    def association(association)
       if self.includes_association?(association)
        @associations[association.to_sym] ||= @base.reflect_on_association(association.to_sym)
      end
    end
    
    # Return the column info for given association and column (if the association is not
    # excluded from search)
    def association_column(association, attr)
      if self.includes_association?(association)
        assoc = self.association(association)
        assoc.klass.columns_hash[attr.to_s] unless assoc.klass._metasearch_exclude_attributes.include?(attr.to_s)
      end
    end
    
    def included_attributes
      @included_attributes ||= @base._metasearch_include_attributes.blank? ?
        @base.column_names - @base._metasearch_exclude_attributes :
        @base.column_names & @base._metasearch_include_attributes
    end
    
    def includes_attribute?(attr)
      self.included_attributes.include?(attr.to_s)
    end
    
    def included_associations
      @included_associations ||= @base._metasearch_include_associations.blank? ?
        @base.reflect_on_all_associations.map {|a| a.name.to_s} - @base._metasearch_exclude_associations :
        @base.reflect_on_all_associations.map {|a| a.name.to_s} & @base._metasearch_include_associations
    end
    
    def includes_association?(assoc)
      self.included_associations.include?(assoc.to_s)
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
      elsif match = matches_association_method(method_id)
        association, attribute, predicate = match.captures
        build_association_method(association, attribute, predicate)
        self.send(preferred_method_name(method_id), *args)
      else
        super
      end
    end
    
    def build_sort_method
      singleton_class.instance_eval do
        define_method(:meta_sort) do
          search_attributes['meta_sort']
        end
      
        define_method(:meta_sort=) do |val|
          column, direction = val.split('.')
          direction ||= 'asc'
          if ['asc','desc'].include?(direction) && attribute = @relation.table[column]
            search_attributes['meta_sort'] = val
            @relation = @relation.order(attribute.send(direction).to_sql)
          end
        end
      end
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
          search_attributes["#{attribute}_#{predicate}"] = cast_attributes(type_for(attribute), val)
          where = Where.new(predicate)
          if where.validate(search_attributes["#{attribute}_#{predicate}"])
            @relation = where.eval(@relation, @relation.table[attribute], search_attributes["#{attribute}_#{predicate}"])
          end
        end
      end
    end
    
    def build_association_method(association, attribute, predicate)
      singleton_class.instance_eval do        
        define_method("#{association}_#{attribute}_#{predicate}") do
          search_attributes["#{association}_#{attribute}_#{predicate}"]
        end
      
        define_method("#{association}_#{attribute}_#{predicate}=") do |val|
          search_attributes["#{association}_#{attribute}_#{predicate}"] = cast_attributes(association_type_for(association, attribute), val)
          where = Where.new(predicate)
          if where.validate(search_attributes["#{association}_#{attribute}_#{predicate}"])
            join = build_or_find_association(association)
            relation = join.relation.is_a?(Array) ? join.relation.last : join.relation
            @relation = where.eval(@relation, relation.table[attribute], search_attributes["#{association}_#{attribute}_#{predicate}"])
          end
        end
      end
    end
    
    def build_or_find_association(association)
      found_association = @join_dependency.join_associations.detect do |assoc|
        assoc.reflection.name == association.to_sym
      end
      unless found_association
        @relation = @relation.joins(association.to_sym)
        @join_dependency.send(:build, association.to_sym, @join_dependency.join_base)
        found_association = @join_dependency.join_associations.last
      end
      found_association
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
      if where.types.include?(type_for(attribute))
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