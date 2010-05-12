module MetaSearch
  NUMBERS = [:integer, :float, :decimal]
  STRINGS = [:string, :text, :binary]
  DATES = [:date]
  TIMES = [:datetime, :timestamp, :time]
  BOOLEANS = [:boolean]
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  DEFAULT_WHERES = [
    ['equals', 'eq'],
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
    ['not_in', 'ni', 'not_in', {:types => ALL_TYPES, :predicate => :not_in}]
  ]
  
  RELATION_METHODS = [:joins, :includes, :all, :count, :to_sql, :paginate, :find_each, :first, :last, :each]
end

require 'active_record'
require 'action_view'
require 'action_controller'
require 'meta_search/searches/active_record'
require 'meta_search/helpers'

ActiveRecord::Base.send(:include, MetaSearch::Searches::ActiveRecord)
ActionView::Helpers::FormBuilder.send(:include, MetaSearch::Helpers::FormBuilder)
ActionController::Base.helper(MetaSearch::Helpers::UrlHelper)
ActionController::Base.helper(MetaSearch::Helpers::FormHelper)