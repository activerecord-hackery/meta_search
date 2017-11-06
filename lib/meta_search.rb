module MetaSearch
  NUMBERS = %i[integer float decimal].freeze
  STRINGS = %i[string text binary].freeze
  DATES = [:date].freeze
  TIMES = %i[datetime timestamp time].freeze
  BOOLEANS = [:boolean].freeze
  ALL_TYPES = NUMBERS + STRINGS + DATES + TIMES + BOOLEANS

  # Change this only if you know what you're doing. It's here for your protection.
  MAX_JOIN_DEPTH = 5

  DEFAULT_WHERES = [
    ['equals', 'eq', validator: proc { |param| !param.blank? || (param == false) }],
    ['does_not_equal', 'ne', 'not_eq', types: ALL_TYPES, predicate: :not_eq],
    ['contains', 'like', 'matches', types: STRINGS, predicate: :matches, formatter: '"%#{param}%"'],
    ['does_not_contain', 'nlike', 'not_matches', types: STRINGS, predicate: :does_not_match, formatter: '"%#{param}%"'],
    ['starts_with', 'sw', types: STRINGS, predicate: :matches, formatter: '"#{param}%"'],
    ['does_not_start_with', 'dnsw', types: STRINGS, predicate: :does_not_match, formatter: '"#{param}%"'],
    ['ends_with', 'ew', types: STRINGS, predicate: :matches, formatter: '"%#{param}"'],
    ['does_not_end_with', 'dnew', types: STRINGS, predicate: :does_not_match, formatter: '"%#{param}"'],
    ['greater_than', 'gt', types: (NUMBERS + DATES + TIMES), predicate: :gt],
    ['less_than', 'lt', types: (NUMBERS + DATES + TIMES), predicate: :lt],
    ['gte', 'gteq', 'greater_than_or_equal_to', types: (NUMBERS + DATES + TIMES), predicate: :gteq],
    ['lte', 'lteq', 'less_than_or_equal_to', types: (NUMBERS + DATES + TIMES), predicate: :lteq],
    ['in', types: ALL_TYPES, predicate: :in],
    ['not_in', 'ni', 'not_in', types: ALL_TYPES, predicate: :not_in],
    ['is_true', types: BOOLEANS, skip_compounds: true],
    ['is_false', types: BOOLEANS, skip_compounds: true, formatter: proc { |param| !param }],
    ['is_present', types: (ALL_TYPES - BOOLEANS), predicate: :not_eq_all, skip_compounds: true, cast: :boolean, formatter: proc { |param| [nil, ''] }],
    ['is_blank', types: (ALL_TYPES - BOOLEANS), predicate: :eq_any, skip_compounds: true, cast: :boolean, formatter: proc { |param| [nil, ''] }],
    ['is_null', types: ALL_TYPES, skip_compounds: true, cast: :boolean, formatter: proc { |param| nil }],
    ['is_not_null', types: ALL_TYPES, predicate: :not_eq, skip_compounds: true, cast: :boolean, formatter: proc { |param| nil }],
    ['between', 'btw', types: (NUMBERS + DATES + TIMES), predicate: :in, formatter: proc { |param| Range.new(param.first, param.last) }, validator: proc { |param| param.is_a?(Array) && !(param[0].blank? || param[1].blank?) }]
  ]

  RELATION_METHODS = [
    # Query construction
    :joins, :includes, :select, :order, :where, :having, :group,
    # Results, debug, array methods
    :to_a, :all, :length, :size, :to_sql, :debug_sql, :paginate, :page,
    :find_each, :first, :last, :each, :arel, :in_groups_of, :group_by,
    # Calculations
    :count, :average, :minimum, :maximum, :sum
  ].freeze
end

require 'active_record'
require 'active_support'
require 'action_view'
require 'action_controller'
require 'meta_search/searches/active_record'
require 'meta_search/helpers'

I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'meta_search', 'locale', '*.yml')]

ActiveRecord::Base.send(:include, MetaSearch::Searches::ActiveRecord)
ActionView::Helpers::FormBuilder.send(:include, MetaSearch::Helpers::FormBuilder)
ActionController::Base.helper(MetaSearch::Helpers::UrlHelper)
ActionController::Base.helper(MetaSearch::Helpers::FormHelper)
