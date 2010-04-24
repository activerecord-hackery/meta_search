module MetaSearch
  NUMBERS = [:integer, :float, :decimal]
  STRINGS = [:string, :text, :binary]
  DATES = [:date]
  TIMES = [:datetime, :timestamp, :time]
  BOOLEANS = [:boolean]
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  DEFAULT_WHERES = [
    ['equals', 'eq'],
    ['does_not_equal', 'ne', 'noteq', {:types => ALL_TYPES, :condition => :noteq}],
    ['contains', 'like', 'matches', {:types => STRINGS, :condition => :matches, :formatter => '"%#{param}%"'}],
    ['does_not_contain', 'nlike', 'notmatches', {:types => STRINGS, :condition => :notmatches, :formatter => '"%#{param}%"'}],
    ['starts_with', 'sw', {:types => STRINGS, :condition => :matches, :formatter => '"#{param}%"'}],
    ['does_not_start_with', 'dnsw', {:types => STRINGS, :condition => :notmatches, :formatter => '"%#{param}%"'}],
    ['ends_with', 'ew', {:types => STRINGS, :condition => :matches, :formatter => '"%#{param}"'}],
    ['does_not_end_with', 'dnew', {:types => STRINGS, :condition => :notmatches, :formatter => '"%#{param}"'}],
    ['greater_than', 'gt', {:types => (NUMBERS + DATES + TIMES), :condition => :gt}],
    ['less_than', 'lt', {:types => (NUMBERS + DATES + TIMES), :condition => :lt}],
    ['greater_than_or_equal_to', 'gte', 'gteq', {:types => (NUMBERS + DATES + TIMES), :condition => :gteq}],
    ['less_than_or_equal_to', 'lte', 'lteq', {:types => (NUMBERS + DATES + TIMES), :condition => :lteq}],
    ['in', {:types => ALL_TYPES, :condition => :in}],
    ['not_in', 'ni', 'notin', {:types => ALL_TYPES, :condition => :notin}]
  ]
  
  RELATION_METHODS = [:joins, :includes, :all, :count, :to_sql, :paginate, :find_each, :first, :last, :each]
end

require 'active_record'
require 'action_view'
require 'meta_search/searches/active_record'
require 'meta_search/helpers/action_view'

ActiveRecord::Base.send(:include, MetaSearch::Searches::ActiveRecord)
ActionView::Helpers::FormBuilder.send(:include, MetaSearch::Helpers::FormBuilder)