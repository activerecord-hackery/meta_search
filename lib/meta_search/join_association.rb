module MetaSearch
  module JoinAssociation

    def self.included(base)
      base.class_eval do
        alias_method_chain :initialize, :polymorphism
        alias_method_chain :build_constraint, :polymorphism
        alias_method :non_polymorphic_equality, :==
        alias_method :==, :polymorphic_equality
      end
    end

    def initialize_with_polymorphism(reflection, join_dependency, parent = nil, polymorphic_class = nil)
      if polymorphic_class && ::ActiveRecord::Base > polymorphic_class
        swapping_reflection_klass(reflection, polymorphic_class) do |reflection|
          initialize_without_polymorphism(reflection, join_dependency, parent)
        end
      else
        initialize_without_polymorphism(reflection, join_dependency, parent)
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

    def polymorphic_equality(other)
      non_polymorphic_equality(other) && active_record == other.active_record
    end

    def build_constraint_with_polymorphism(reflection, table, key, foreign_table, foreign_key)
      if reflection.options[:polymorphic]
        build_constraint_without_polymorphism(reflection, table, key, foreign_table, foreign_key).and(
          foreign_table[reflection.foreign_type].eq(reflection.klass.name)
        )
      else
        build_constraint_without_polymorphism(reflection, table, key, foreign_table, foreign_key)
      end
    end

  end
end