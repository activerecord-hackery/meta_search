module MetaSearch
  NUMBERS = [:integer, :float, :decimal]
  STRINGS = [:string, :text, :binary]
  DATES = [:date]
  TIMES = [:datetime, :timestamp, :time]
  BOOLEANS = [:boolean]
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  # Change this only if you know what you're doing. It's here for your protection.
  MAX_JOIN_DEPTH = 5

  DEFAULT_WHERES = [
    ['equals', 'eq', {:validator => Proc.new {|param| !param.blank? || (param == false)}}],
    ['does_not_equal', 'ne', 'not_eq', {:types => ALL_TYPES, :predicate => :not_eq}],
    ['contains', 'like', 'matches', {:types => STRINGS, :predicate => :matches, :formatter => '"%#{param}%"'}],
    ['does_not_contain', 'nlike', 'not_matches', {:types => STRINGS, :predicate => :not_matches, :formatter => '"%#{param}%"'}],
    ['starts_with', 'sw', {:types => STRINGS, :predicate => :matches, :formatter => '"#{param}%"'}],
    ['does_not_start_with', 'dnsw', {:types => STRINGS, :predicate => :not_matches, :formatter => '"%#{param}%"'}],
    ['ends_with', 'ew', {:types => STRINGS, :predicate => :matches, :formatter => '"%#{param}"'}],
    ['does_not_end_with', 'dnew', {:types => STRINGS, :predicate => :not_matches, :formatter => '"%#{param}"'}],
    ['greater_than', 'gt', {:types => (NUMBERS + DATES + TIMES), :predicate => :gt}],
    ['less_than', 'lt', {:types => (NUMBERS + DATES + TIMES), :predicate => :lt}],
    ['greater_than_or_equal_to', 'gte', 'gteq', {:types => (NUMBERS + DATES + TIMES), :predicate => :gteq}],
    ['less_than_or_equal_to', 'lte', 'lteq', {:types => (NUMBERS + DATES + TIMES), :predicate => :lteq}],
    ['in', {:types => ALL_TYPES, :predicate => :in}],
    ['not_in', 'ni', 'not_in', {:types => ALL_TYPES, :predicate => :not_in}],
    ['is_true', {:types => BOOLEANS, :skip_compounds => true}],
    ['is_false', {:types => BOOLEANS, :skip_compounds => true, :formatter => Proc.new {|param| !param}}],
    ['is_present', {:types => (NUMBERS + STRINGS), :predicate => :not_eq_all, :splat_param => true, :skip_compounds => true, :cast => :boolean, :formatter => Proc.new {|param| [nil, '']}}],
    ['is_blank', {:types => (NUMBERS + STRINGS), :predicate => :eq_any, :splat_param => true, :skip_compounds => true, :cast => :boolean, :formatter => Proc.new {|param| [nil, '']}}],
    ['is_null', {:types => ALL_TYPES, :skip_compounds => true, :cast => :boolean, :formatter => Proc.new {|param| nil}}],
    ['is_not_null', {:types => ALL_TYPES, :predicate => :not_eq, :skip_compounds => true, :cast => :boolean, :formatter => Proc.new {|param| nil}}]
  ]

  RELATION_METHODS = [:joins, :includes, :select, :order, :where, :having,
                      :to_a, :all, :count, :length, :size, :to_sql, :debug_sql, :paginate,
                      :find_each, :first, :last, :each, :arel]
end

require 'active_record'
require 'active_support'
require 'action_view'
require 'action_controller'
require 'meta_search/join_dependency'
require 'meta_search/searches/active_record'
require 'meta_search/helpers'

ActiveRecord::Associations::ClassMethods::JoinDependency.send(:include, MetaSearch::JoinDependency)
ActiveRecord::Base.send(:include, MetaSearch::Searches::ActiveRecord)
ActionView::Helpers::FormBuilder.send(:include, MetaSearch::Helpers::FormBuilder)
ActionController::Base.helper(MetaSearch::Helpers::UrlHelper)
ActionController::Base.helper(MetaSearch::Helpers::FormHelper)