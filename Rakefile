require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

def run_tests
  	Dir.glob('test/{unit,functional}/*_test.rb').each do |fn|
		load fn
	end
end

desc 'Runs the plugin tests in offline mode'
task :offline_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'offline_test'
	run_tests
end

desc 'Runs the plugin tests in online mode'
task :online_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'test'
	run_tests
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
