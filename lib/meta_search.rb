module MetaSearch
  NUMBERS = [:integer, :float, :decimal]
  STRINGS = [:string, :text, :binary]
  DATES = [:date]
  TIMES = [:datetime, :timestamp, :time]
  BOOLEANS = [:boolean]
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  DEFAULT_WHERES = [
    ['equals', 'eq'],
    ['does_not_equal', 'ne', {:types => ALL_TYPES, :condition => '!='}],
    ['contains', 'like', {:types => STRINGS, :condition => 'LIKE', :formatter => '"%#{param}%"'}],
    ['does_not_contain', 'nlike', {:types => STRINGS, :condition => 'NOT LIKE', :formatter => '"%#{param}%"'}],
    ['starts_with', 'sw', {:types => STRINGS, :condition => 'LIKE', :formatter => '"#{param}%"'}],
    ['does_not_start_with', 'dnsw', {:types => STRINGS, :condition => 'NOT LIKE', :formatter => '"%#{param}%"'}],
    ['ends_with', 'ew', {:types => STRINGS, :condition => 'LIKE', :formatter => '"%#{param}"'}],
    ['does_not_end_with', 'dnew', {:types => STRINGS, :condition => 'NOT LIKE', :formatter => '"%#{param}"'}],
    ['greater_than', 'gt', {:types => (NUMBERS + DATES + TIMES), :condition => '>'}],
    ['less_than', 'lt', {:types => (NUMBERS + DATES + TIMES), :condition => '<'}],
    ['greater_than_or_equal_to', 'gte', {:types => (NUMBERS + DATES + TIMES), :condition => '>='}],
    ['less_than_or_equal_to', 'lte', {:types => (NUMBERS + DATES + TIMES), :condition => '<='}]
  ]
  
  RELATION_METHODS = [:joins, :includes, :all, :count, :to_sql, :paginate, :find_each, :first, :last, :each]
end

if defined?(::Rails::Railtie)
  require 'meta_search/railtie'
end