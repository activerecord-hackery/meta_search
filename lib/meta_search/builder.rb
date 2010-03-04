require 'meta_search/model_compatibility'

module MetaSearch
  class Builder
    include ModelCompatibility
    
    attr_reader :model, :attributes, :relation, :join_dependency
    delegate :all, :count, :to_sql, :to => :relation
    
    NUMBERS = [:integer, :float, :decimal]
    STRINGS = [:string, :text, :binary]
    DATES = [:date]
    TIMES = [:datetime, :timestamp, :time]
    BOOLEANS = [:boolean]
    ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS
    
    WHERES = [
      ['equals', {:types => ALL_TYPES, :conditional => '=', :substitutions => '?',
        :params => 'args.first', :name => "equals"}],
      ['does_not_equal', {:types => ALL_TYPES, :conditional => '!=', :substitutions => '?',
        :params => 'args.first', :name => "does_not_equal"}],
      ['contains', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
        :params => '"%#{args.first}%"', :name => 'contains'}],
      ['does_not_contain', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
        :params => '"%#{args.first}%"', :name => 'does_not_contain'}],
      ['starts_with', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
        :params => '"#{args.first}%"', :name => 'starts_with'}],
      ['does_not_start_with', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
        :params => '"%#{args.first}%"', :name => 'does_not_start_with'}],
      ['ends_with', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
        :params => '"%#{args.first}"', :name => 'ends_with'}],
      ['does_not_end_with', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
        :params => '"%#{args.first}"', :name => 'does_not_end_with'}],
      ['greater_than', {:types => (NUMBERS + DATES + TIMES), :conditional => '>', :substitutions => '?',
        :params => 'args.first', :name => 'greater_than'}],
      ['less_than', {:types => (NUMBERS + DATES + TIMES), :conditional => '<', :substitutions => '?',
        :params => 'args.first', :name => 'less_than'}],
      ['greater_than_or_equal_to', {:types => (NUMBERS + DATES + TIMES), :conditional => '>=', :substitutions => '?',
        :params => 'args.first', :name => 'greater_than_or_equal_to'}],
      ['less_than_or_equal_to', {:types => (NUMBERS + DATES + TIMES), :conditional => '<=', :substitutions => '?',
        :params => 'args.first', :name => 'less_than_or_equal_to'}]
    ]

    def initialize(model, opts = {})
      @model = model
      @association_names = @model.reflect_on_all_associations.map {|a| a.name}
      @associations = {}
      @join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@model, [], nil)
      @opts = opts
      @attributes = {}
      @relation = @model.scoped
    end
    
    def column(attribute)
      @model.columns_hash[attribute.to_s]
    end
    
    def association(association)
      if @association_names.include?(association.to_sym)
        @associations[association.to_sym] ||= @model.reflect_on_association(association.to_sym)
      end
    end
    
    def association_column(association, column)
      self.association(association).klass.columns_hash[column.to_s] rescue nil
    end
    
    def build(opts)
      opts ||= {}
      @relation = @model.scoped
      opts.stringify_keys!
      opts = collapse_multiparameter_options(opts)
      assign_attributes(opts)
      self
    end
    

    def add_where_method(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      args = args.compact.flatten.map {|a| a.to_s }
      raise ArgumentError, "Name parameter required" if args.blank?
      opts[:name] = args.first
      opts[:types] ||= ALL_TYPES
      opts[:types].flatten!
      opts[:conditional] ||= '='
      opts[:substitutions] ||= '?'
      opts[:params] ||= 'args.first'
      WHERES.push [*args, opts]
    end
    
    private
    
    def cast_attribute(type, val)
      case type
      when *STRINGS
        String.new(val)
      when *DATES
        y, m, d = *[val].flatten
        m ||= 1
        d ||= 1
        Date.new(y,m,d) rescue nil
      when *TIMES
        y, m, d, hh, mm, ss = *[val].flatten
        Time.zone.local(y, m, d, hh, mm, ss) rescue nil
      when *BOOLEANS
        ActiveRecord::ConnectionAdapters::Column.value_to_boolean(val)
      when :integer
        val.blank? ? nil : val.to_i
      when :float
        val.blank? ? nil : val.to_f
      when :decimal
        val.blank? ? nil : ActiveRecord::ConnectionAdapters::Column.value_to_decimal(val)
      else
        raise ArgumentError, "Unable to cast columns of type #{type}"
      end
    end
    
    def method_missing(method_id, *args, &block)
      if match = matches_attribute_method(method_id)
        condition, attribute, association = match.captures.reverse
        build_method(association, attribute, condition)
        self.send(method_id, *args)
      elsif match = matches_where_method(method_id)
        condition = match.captures.first
        build_where_method(condition, get_where(condition))
        self.send(method_id, *args)
      else
        super
      end
    end
    
    def build_method(association, attribute, suffix)
      if association.blank?
        build_attribute_method(attribute, suffix)
      else
        build_association_method(association, attribute, suffix)
      end
    end
    
    def build_association_method(association, attribute, type)
      metaclass.instance_eval do        
        define_method("#{association}_#{attribute}_#{type}") do
          attributes["#{association}_#{attribute}_#{type}"]
        end
      
        define_method("#{association}_#{attribute}_#{type}=") do |val|
          attributes["#{association}_#{attribute}_#{type}"] = cast_attribute(association_type_for(association, attribute), val)
          unless attributes["#{association}_#{attribute}_#{type}"].blank?
            join = build_or_find_association(association)
            self.send("add_#{type}_where", join.aliased_table_name, attribute, attributes["#{association}_#{attribute}_#{type}"])
          end
        end
      end
    end
    
    def build_attribute_method(attribute, type)
      metaclass.instance_eval do
        define_method("#{attribute}_#{type}") do
          attributes["#{attribute}_#{type}"]
        end
      
        define_method("#{attribute}_#{type}=") do |val|
          attributes["#{attribute}_#{type}"] = cast_attribute(type_for(attribute), val)
          unless attributes["#{attribute}_#{type}"].blank?
            self.send("add_#{type}_where", @model.table_name, attribute, attributes["#{attribute}_#{type}"])
          end
        end
      end
    end
    
    def build_where_method(condition, opts)
      metaclass.instance_eval do
        define_method("add_#{condition}_where") do |table, attribute, *args|
          @relation = @relation.where(
            "#{quote_table_name table}.#{quote_column_name attribute} " + 
            "#{opts[:conditional]} #{opts[:substitutions]}", eval(opts[:params])
          )
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
    
    
    def matches_attribute_method(method_id)
      method_name, where = preferred_method_name_and_where(method_id)
      return nil unless method_name
      match = method_name.match("^(.*)_(#{where[:name]})$")
      attribute, condition = match.captures
      if where[:types].include?(type_for(attribute))
        return match
      elsif match = matches_association(method_name, attribute, condition)
        association, attribute = match.captures
        return match if where[:types].include?(association_type_for(association, attribute))
      end
      nil
    end
    
    def preferred_method_name_and_where(method_id)
      method_name = method_id.to_s.sub(/=$/, '')
      WHERES.each do |names|
        opts = names.last
        if name = names.detect {|n| method_name =~ /#{n}$/}
          return [method_name.sub(/#{name}/, opts[:name]), opts]
        end
      end
      nil
    end
    
    def matches_association(method_id, attribute, condition)
      @association_names.each do |association|
        test_attribute = attribute.dup
        if test_attribute.gsub!(/^#{association}_/, '') &&
          match = method_id.to_s.match("^(#{association})_(#{test_attribute})_(#{condition})=?$")
          return match
        end
      end
      nil
    end
    
    def matches_where_method(method_id)
      if match = method_id.to_s.match(/^add_(.*)_where$/)
        condition = match.captures.first
        get_where(condition) ? match : nil
      end
    end
    
    def get_where(condition)
      WHERES.detect {|w| w.include?(condition)}.to_a.last
    end
    
    def assign_attributes(opts)
      opts.each_pair do |k, v|
        self.send("#{k}=", v)
      end
    end
    
    def collapse_multiparameter_options(opts)
      opts.each_key do |k|
        if k.include?("(")
          real_attribute, position = k.split(/\(|\)/)
          cast = %w(a s i).include?(position.last) ? position.last : nil
          position = position.to_i - 1
          value = opts.delete(k)
          opts[real_attribute] ||= []
          opts[real_attribute][position] = if cast
            (value.blank? && cast == 'i') ? nil : value.send("to_#{cast}")
          else
            value
          end
        end
      end
      opts
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
    
    def quote_table_name(name)
      ActiveRecord::Base.connection.quote_table_name(name)
    end
    
    def quote_column_name(name)
      ActiveRecord::Base.connection.quote_column_name(name)
    end
    
    def set_default_wheres
      [
        ['equals', {:types => ALL_TYPES, :conditional => '=', :substitutions => '?',
          :params => 'args.first', :name => "equals"}],
        ['does_not_equal', {:types => ALL_TYPES, :conditional => '!=', :substitutions => '?',
          :params => 'args.first', :name => "does_not_equal"}],
        ['contains', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
          :params => '"%#{args.first}%"', :name => 'contains'}],
        ['does_not_contain', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
          :params => '"%#{args.first}%"', :name => 'does_not_contain'}],
        ['starts_with', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
          :params => '"#{args.first}%"', :name => 'starts_with'}],
        ['does_not_start_with', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
          :params => '"%#{args.first}%"', :name => 'does_not_start_with'}],
        ['ends_with', {:types => STRINGS, :conditional => 'LIKE', :substitutions => '?',
          :params => '"%#{args.first}"', :name => 'ends_with'}],
        ['does_not_end_with', {:types => STRINGS, :conditional => 'NOT LIKE', :substitutions => '?',
          :params => '"%#{args.first}"', :name => 'does_not_end_with'}],
        ['greater_than', {:types => (NUMBERS + DATES + TIMES), :conditional => '>', :substitutions => '?',
          :params => 'args.first', :name => 'greater_than'}],
        ['less_than', {:types => (NUMBERS + DATES + TIMES), :conditional => '<', :substitutions => '?',
          :params => 'args.first', :name => 'less_than'}],
        ['greater_than_or_equal_to', {:types => (NUMBERS + DATES + TIMES), :conditional => '>=', :substitutions => '?',
          :params => 'args.first', :name => 'greater_than_or_equal_to'}],
        ['less_than_or_equal_to', {:types => (NUMBERS + DATES + TIMES), :conditional => '<=', :substitutions => '?',
          :params => 'args.first', :name => 'less_than_or_equal_to'}]
      ]
    end
  end
end