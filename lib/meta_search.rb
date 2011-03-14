require 'meta_search/configuration'

module MetaSearch
  extend Configuration
end

MetaSearch.configure do |config|
  MetaSearch::Constants::AREL_PREDICATES.each do |name|
    config.add_predicate name, :arel_predicate => name
  end

  MetaSearch::Constants::DERIVED_PREDICATES.each do |args|
    config.add_predicate *args
  end
end

require 'meta_search/translate'
require 'meta_search/search'
require 'meta_search/adapters/active_record'
require 'meta_search/helpers'
require 'action_controller'

ActiveRecord::Base.extend MetaSearch::Adapters::ActiveRecord::Base
ActionController::Base.helper MetaSearch::Helpers::FormHelper