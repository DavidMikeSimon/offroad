require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

def common_test_settings(t)
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the <%= file_name %> plugin.'
Rake::TestTask.new(:test) do |t|
  common_test_settings(t)
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rcov/rcovtask'
  
  Rcov::RcovTask.new(:rcov) do |t|
    common_test_settings(t)
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