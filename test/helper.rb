require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'active_support/time'
require 'active_record'
require 'active_record/fixtures'
require 'action_view'
require 'meta_search'

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

Time.zone = 'Eastern Time (US & Canada)'

ActiveRecord::Base.establish_connection(
  :adapter => defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3',
  :database => ':memory:'
)

dep = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : ::Dependencies
dep.autoload_paths.unshift FIXTURES_PATH

ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false
  load File.join(FIXTURES_PATH, 'schema.rb')
end

ActiveRecord::Fixtures.create_fixtures(FIXTURES_PATH, ActiveRecord::Base.connection.tables)

I18n.load_path += Dir[File.join(File.dirname(__FILE__), 'locales', '*.yml')]

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

class Test::Unit::TestCase
  def self.context_a_search_against(name, object, &block)
    context "A search against #{name}" do
      setup do
        @s = object.search
      end

      merge_block(&block) if block_given?
    end
  end
end
