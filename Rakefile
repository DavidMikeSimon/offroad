require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Runs the plugin tests in offline mode'
task :offline_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'offline_test'
	Rake::Task["internal_test"].invoke
end

desc 'Runs the plugin tests in online mode'
task :online_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'test'
	Rake::Task["internal_test"].invoke
end

Rake::TestTask.new(:internal_test) do |t|
  	t.libs << 'lib'
  	t.libs << 'test'
  	t.verbose = true
  	t.pattern = 'test/{unit,functional}/*_test.rb'
	RAILS_ENV = ENV['RAILS_ENV'] = "test"
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
