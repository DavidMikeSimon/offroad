require 'rake'
require 'rake/rdoctask'

def run_tests(desc)
  # Doing it this way because the regular rake testtask way had magic that didn't work properly for me
  Dir.glob('test/{unit,functional}/*_test.rb').each do |fn|
    puts ""
    puts ""
    puts ""
    puts "*"*50
    puts "**** RUNNING %s TEST %s" % [desc, fn]
    puts "*"*50
    load fn
  end
  puts ""
end

task :default => [:test]

desc 'Runs both the offline and online tests'
task :test do
  [:offline_test, :online_test].each do |taskname|
    id = fork # Forking so that we can initialize two different Rails environments
    if id
      # Parent process; wait for the child process to end
      Process.wait id
    else
      # Child process; run the rake task then end process
      puts ""
      puts ""
      puts ""
      puts "!"*80
      puts "!!!! BEGINNING FORKED RAKE TASK %s" % taskname.to_s
      puts "!"*80
      Rake::Task[taskname].invoke
      exit!
    end
  end
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
