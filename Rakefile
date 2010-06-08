require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "meta_search"
    gem.summary = %Q{ActiveRecord 3 object-based searching for your form_for enjoyment.}
    gem.description = %Q{
      Allows simple search forms to be created against an AR3 model
      and its associations, has useful view helpers for sort links
      and multiparameter fields as well.
    }
    gem.email = "ernie@metautonomo.us"
    gem.homepage = "http://metautonomo.us/projects/metasearch/"
    gem.authors = ["Ernie Miller"]
    gem.add_development_dependency "shoulda"
    gem.add_dependency "activerecord", ">= 3.0.0.beta4"
    gem.add_dependency "activesupport", ">= 3.0.0.beta4"
    gem.add_dependency "actionpack", ">= 3.0.0.beta4"
    gem.add_dependency "arel", ">= 0.4.0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.libs << 'vendor/rails/activerecord/lib'
  test.libs << 'vendor/rails/activesupport/lib'
  test.libs << 'vendor/rails/actionpack/lib'
  test.libs << 'vendor/arel/lib'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

# Don't check dependencies on test, we're using vendored libraries
# task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "meta_search #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
