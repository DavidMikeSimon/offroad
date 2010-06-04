require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'cgi'

begin
  require 'rcov'
rescue
end

def run_tests(desc)
  analyzer = nil
  if $rcov_enabled
    begin
      fh = File.open($rcov_data_filename)
      analyzer = Marshal.load(fh)
      fh.close
      puts "*** Loaded prior rcov data for aggregation"
    rescue
      analyzer = Rcov::CodeCoverageAnalyzer.new
      puts "*** Created new rcov data"
    end
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
  
  if $rcov_enabled
    fh = File.open($rcov_data_filename, "w")
    Marshal.dump(analyzer, fh)
    fh.close
    puts "*** Saved rcov data"
  end
  
  puts ""
end

def coverage_report
  return unless $rcov_enabled
  
  puts "Writing coverage analysis..."
  formatter = Rcov::HTMLCoverage.new(
    :ignore => [/\Wruby\W/, /\Wgems\W/, /^test\W/],
    :destdir => "coverage"
  )
  fh = File.open($rcov_data_filename)
  analyzer = Marshal.load(fh)
  fh.close
  analyzer.dump_coverage_info([formatter])
  
  File.delete($rcov_data_filename)
end

task :default => [:test]

desc 'Uses rcov for coverage-testing following tests'
task :rcov do
  $rcov_enabled = true
  $rcov_data_filename = "rcov-%u.tmp" % Time.now.to_i
end

desc 'Runs both the offline and online tests'
task :test do
  ["OFFLINE", "ONLINE"].each do |desc|
    id = fork # Forking so that we can start different Rails environments
    if id
      # Parent process; wait for the child process to end
      Process.wait id
    else
      # Child process; run the rake task then end process
      puts ""
      puts "!"*80
      puts "!!!! BEGINNING FORKED TEST %s" % desc.to_s
      puts "!"*80
      
      case desc
      when "OFFLINE"
        RAILS_ENV = ENV["RAILS_ENV"] = "offline_test"
      when "ONLINE"
        RAILS_ENV = ENV["RAILS_ENV"] = "test"
      end
      
      run_tests(desc)
      exit!
    end
  end
  
  coverage_report
end

desc 'Runs the plugin tests in offline mode'
task :offline_test do
  RAILS_ENV = ENV["RAILS_ENV"] = "offline_test"
  run_tests("OFFLINE")
  coverage_report
end

desc 'Runs the plugin tests in online mode'
task :online_test do
  RAILS_ENV = ENV["RAILS_ENV"] = "test"
  run_tests("ONLINE")
  coverage_report
end

desc 'Generate documentation for the offline_mirror plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'OfflineMirror'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
