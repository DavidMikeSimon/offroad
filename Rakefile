require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

def common_test_settings(t)
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Default: run unit and functional tests.'
task :default => :test

desc 'Test Offroad'
Rake::TestTask.new(:test) do |t|
  common_test_settings(t)
end

desc 'Generate documentation for Offroad.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Offroad'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rcov/rcovtask'
  
  Rcov::RcovTask.new(:rcov) do |t|
    common_test_settings(t)
    t.pattern = 'test/unit/*_test.rb' # Don't care about coverage added by functional tests
    t.rcov_opts << '-o coverage -x "/ruby/,/gems/,/test/,/migrate/"'
  end
rescue LoadError
  # Rcov wasn't available
end

begin
  require 'ruby-prof/task'
  
  RubyProf::ProfileTask.new(:profile) do |t|
    common_test_settings(t)
    t.output_dir = "#{File.dirname(__FILE__)}/profile"
    t.printer = :call_tree
    t.min_percent = 10
  end
rescue LoadError
  # Ruby-prof wasn't available
end

require 'lib/version'
gemspec = Gem::Specification.new do |s|
  s.name         = "offroad"
  s.version      = Offroad::VERSION
  s.authors      = ["David Mike Simon"]
  s.email        = "david.mike.simon@gmail.com"
  s.homepage     = "http://github.com/DavidMikeSimon/offroad"
  s.summary      = "Manages off-Internet instances of a Rails app"
  s.description  = "Offroad manages offline instances of a Rails app on computers without Internet access. The online and offline instances can communicate via mirror files, transported by the user via thumbdrive, burned CD, etc."

  s.files        = `git ls-files .`.split("\n") - [".gitignore"]
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'

  s.add_dependency('ar-extensions', '0.9.4')
end

Rake::GemPackageTask.new(gemspec) do |pkg|
end
