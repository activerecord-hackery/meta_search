require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'active_record'
require 'active_record/fixtures'
require 'action_view'

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

dep = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : ::Dependencies
dep.load_paths.unshift FIXTURES_PATH

ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false
  load File.join(FIXTURES_PATH, 'schema.rb')
end

Fixtures.create_fixtures(FIXTURES_PATH, ActiveRecord::Base.connection.tables)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'meta_search'
require 'meta_search/searches/active_record'
require 'meta_search/helpers/action_view'

MetaSearch::Searches::ActiveRecord.enable!
MetaSearch::Helpers::FormBuilder.enable!

class Test::Unit::TestCase
end
