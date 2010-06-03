require 'rubygems'
require 'rake'
require 'rake/rdoctask'

begin
  require 'rcov'
rescue
end

def run_tests(desc)
  analyzer = nil
  if $rcov_enabled
    analyzer = Rcov::CodeCoverageAnalyzer.new
  end
  
  # The regular rake testtask way had magic that didn't work properly for me
  Dir.glob('test/{unit,functional}/*_test.rb').each do |fn|
    puts ""
    puts ""
    puts "#"*20 + " " + fn
    if $rcov_enabled
      analyzer.run_hooked do
        load fn
      end
    else
      load fn
    end
  end
                                 
  puts ""
  
  if $rcov_enabled
    puts "Writing coverage analysis..."
    formatter = Rcov::HTMLCoverage.new(
      :ignore => [/\Wruby\W/, /\Wgems\W/, /^test\W/],
      :destdir => "%s-coverage" % desc.downcase
    )
    analyzer.dump_coverage_info([formatter])
  end
end

task :default => [:test]

desc 'Uses rcov for coverage-testing following tests'
task :rcov do
  $rcov_enabled = true
end

desc 'Runs both the offline and online tests'
task :test do
  [:offline_test, :online_test].each do |taskname|
    id = fork # Forking so that we can start different Rails environments
    if id
      # Parent process; wait for the child process to end
      Process.wait id
    else
      # Child process; run the rake task then end process
      puts ""
      puts "!"*80
      puts "!!!! BEGINNING FORKED TEST %s" % taskname.to_s
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
