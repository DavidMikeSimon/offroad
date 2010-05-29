require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

def set_common_test_attrs(t)
  t.libs << 'lib'
  t.libs << 'test'
  t.verbose = true
end

Rake::TestTask.new(:online_test) do |t|
	set_common_test_attrs(t)
	t.pattern = 'test/{online,common}/**/*_test.rb'
end

Rake::TestTask.new(:offline_test) do |t|
	RAILS_ENV = ENV['RAILS_ENV'] = 'offline-test'
	set_common_test_attrs(t)
	t.pattern = 'test/{offline,common}/**/*_test.rb'
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
