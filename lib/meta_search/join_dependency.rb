module MetaSearch

  module JoinDependency

    class JoinAssociation < ::ActiveRecord::Associations::JoinDependency::JoinAssociation

      def initialize(reflection, join_dependency, parent = nil, polymorphic_class = nil)
        if polymorphic_class && ::ActiveRecord::Base > polymorphic_class
          swapping_reflection_klass(reflection, polymorphic_class) do |reflection|
            super(reflection, join_dependency, parent)
          end
        else
          super(reflection, join_dependency, parent)
        end
      end

      def swapping_reflection_klass(reflection, klass)
        reflection = reflection.clone
        original_polymorphic = reflection.options.delete(:polymorphic)
        reflection.instance_variable_set(:@klass, klass)
        yield reflection
      ensure
        reflection.options[:polymorphic] = original_polymorphic
      end

      def ==(other)
        super && active_record == other.active_record
      end

      def build_constraint(reflection, table, key, foreign_table, foreign_key)
        if reflection.options[:polymorphic]
          super.and(
            foreign_table[reflection.foreign_type].eq(reflection.klass.name)
          )
        else
          super
        end
      end

    end

    # Yes, I'm using alias_method_chain here. No, I don't feel too
    # bad about it. JoinDependency, or, to call it by its full proper
    # name, ::ActiveRecord::Associations::JoinDependency, is one of the
    # most "for internal use only" chunks of ActiveRecord.
    def self.included(base)
      base.class_eval do
        alias_method_chain :graft, :meta_search
      end
    end

    def graft_with_meta_search(*associations)
      associations.each do |association|
        join_associations.detect {|a| association == a} ||
          build_polymorphic(association.reflection.name, association.find_parent_in(self) || join_base, association.join_type, association.reflection.klass)
      end
      self
    end

    # Should only be called by MetaSearch, and only with a single association name
    def build_polymorphic(association, parent = nil, join_type = Arel::OuterJoin, klass = nil)
      parent ||= join_parts.last
      reflection = parent.reflections[association] or
        raise ::ActiveRecord::ConfigurationError, "Association named '#{ association }' was not found; perhaps you misspelled it?"
      unless join_association = find_join_association_respecting_polymorphism(reflection, parent, klass)
        @reflections << reflection
        join_association = build_join_association_respecting_polymorphism(reflection, parent, klass)
        join_association.join_type = join_type
        @join_parts << join_association
        cache_joined_association(join_association)
      end

      join_association
    end

    def find_join_association_respecting_polymorphism(reflection, parent, klass)
      if association = find_join_association(reflection, parent)
        unless reflection.options[:polymorphic]
          association
        else
          association if association.active_record == klass
        end
      end
    end

    def build_join_association_respecting_polymorphism(reflection, parent, klass = nil)
      if reflection.options[:polymorphic] && klass
        JoinAssociation.new(reflection, self, parent, klass)
      else
        JoinAssociation.new(reflection, self, parent)
      end
    end
  end
end