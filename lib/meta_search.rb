module MetaSearch
  NUMBERS = [:integer, :float, :decimal]
  STRINGS = [:string, :text, :binary]
  DATES = [:date]
  TIMES = [:datetime, :timestamp, :time]
  BOOLEANS = [:boolean]
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  DEFAULT_WHERES = [
    ['equals', 'eq'],
    ['does_not_equal', 'ne', {:types => ALL_TYPES, :conditional => '!='}],
    ['contains', 'like', {:types => STRINGS, :conditional => 'LIKE', :formatter => '"%#{param}%"'}],
    ['does_not_contain', 'nlike', {:types => STRINGS, :conditional => 'NOT LIKE', :formatter => '"%#{param}%"'}],
    ['starts_with', 'sw', {:types => STRINGS, :conditional => 'LIKE', :formatter => '"#{param}%"'}],
    ['does_not_start_with', 'dnsw', {:types => STRINGS, :conditional => 'NOT LIKE', :formatter => '"%#{param}%"'}],
    ['ends_with', 'ew', {:types => STRINGS, :conditional => 'LIKE', :formatter => '"%#{param}"'}],
    ['does_not_end_with', 'dnew', {:types => STRINGS, :conditional => 'NOT LIKE', :formatter => '"%#{param}"'}],
    ['greater_than', 'gt', {:types => (NUMBERS + DATES + TIMES), :conditional => '>'}],
    ['less_than', 'lt', {:types => (NUMBERS + DATES + TIMES), :conditional => '<'}],
    ['greater_than_or_equal_to', 'gte', {:types => (NUMBERS + DATES + TIMES), :conditional => '>='}],
    ['less_than_or_equal_to', 'lte', {:types => (NUMBERS + DATES + TIMES), :conditional => '<='}]
  ]
  
  require 'active_record'
  require 'meta_search/builder'
  require 'meta_search/search'
  
  class << self
    def add_search_to_active_record
      return if ActiveRecord::Base.respond_to? :search
      ActiveRecord::Base.send :include, Search
    end
  end
end

if defined? Rails
  MetaSearch.add_search_to_active_record
end