require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

def run_tests(desc)
	# Running tests this strange way due to odd ActiveSupport::Dependencies issues.
	# Maybe will try again to resolve them later, but it's low priority.
	# Better to have an odd but working test suite than a standard one that's broken...
  	Dir.glob('test/{unit,functional}/*_test.rb').each do |fn|
		id = fork
		if id
			# In parent; wait for child to finish
			Process.wait id
		else
			# In child; load the tests then finish the rake task, which will cause the tests to run
			puts ""
			puts ""
			puts ""
			puts "*"*50
			puts "**** RUNNING %s TEST %s" % [desc, fn]
			puts "*"*50
			load fn
			break
		end
	end
	puts ""
end

desc 'Runs the plugin tests in offline mode'
task :offline_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'offline_test'
	run_tests("OFFLINE")
end

desc 'Runs the plugin tests in online mode'
task :online_test do
	RAILS_ENV = ENV["RAILS_ENV"] = 'test'
	run_tests("ONLINE")
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
