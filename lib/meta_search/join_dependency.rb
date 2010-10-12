module MetaSearch

  module JoinDependency

    def self.included(base)
      base.class_eval do
        alias_method_chain :graft, :metasearch
      end
    end

    def graft_with_metasearch(*associations)
      associations.each do |association|
        join_associations.detect {|a| association == a} ||
        (
          association.class == MetaSearch::PolymorphicJoinAssociation ?
          build_with_metasearch(association.reflection.name, association.find_parent_in(self) || join_base, association.join_class, association.reflection.klass) :
          build(association.reflection.name, association.find_parent_in(self) || join_base, association.join_class)
        )
      end
      self
    end

    protected

      def build_with_metasearch(association, parent = nil, join_class = Arel::InnerJoin, polymorphic_class = nil)
        parent ||= @joins.last
        case association
        when Symbol, String
          reflection = parent.reflections[association.to_s.intern] or
          raise ConfigurationError, "Association named '#{ association }' was not found; perhaps you misspelled it?"
          if reflection.options[:polymorphic]
            @reflections << reflection
            @joins << build_polymorphic_join_association(reflection, parent, polymorphic_class).with_join_class(join_class)
          else
            @reflections << reflection
            @joins << build_join_association(reflection, parent).with_join_class(join_class)
          end
        else
          build(association, parent, join_class) # Shouldn't get here.
        end
      end

      def build_polymorphic_join_association(reflection, parent, klass)
        PolymorphicJoinAssociation.new(reflection, self, klass, parent)
      end
  end

  class PolymorphicJoinAssociation < ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation

    def initialize(reflection, join_dependency, polymorphic_class, parent = nil)
      reflection.check_validity!
      @active_record = polymorphic_class
      @cached_record = {}
      @join_dependency    = join_dependency
      @parent             = parent || join_dependency.join_base
      @reflection         = reflection.clone
      @reflection.instance_eval "def klass; #{polymorphic_class} end"
      @aliased_prefix     = "t#{ join_dependency.joins.size }"
      @parent_table_name  = @parent.active_record.table_name
      @aliased_table_name = aliased_table_name_for(table_name)
      @join               = nil
      @join_class         = Arel::InnerJoin
    end

    def ==(other)
      other.class == self.class &&
      other.reflection == reflection &&
      other.active_record == active_record &&
      other.parent == parent
    end

    def association_join
      return @join if @join

      aliased_table = Arel::Table.new(table_name, :as => @aliased_table_name, :engine => arel_engine)
      parent_table = Arel::Table.new(parent.table_name, :as => parent.aliased_table_name, :engine => arel_engine)

      @join = [
        aliased_table[options[:primary_key] || reflection.klass.primary_key].eq(parent_table[options[:foreign_key] || reflection.primary_key_name]),
        parent_table[options[:foreign_type]].eq(active_record.base_class.name)
      ]

      unless klass.descends_from_active_record?
        sti_column = aliased_table[klass.inheritance_column]
        sti_condition = sti_column.eq(klass.sti_name)
        klass.descendants.each {|subclass| sti_condition = sti_condition.or(sti_column.eq(subclass.sti_name)) }

        @join << sti_condition
      end

      @join
    end
  end
end