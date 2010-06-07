# Load the Rails environment
require "#{File.dirname(__FILE__)}/app_root/config/environment"
require 'test_help'
require 'test/unit'
require 'test/unit/ui/console/testrunner'
require 'test/unit/util/backtracefilter'

silence_warnings do
  # Undo changes to RAILS_ENV made by Rails' test_help
  RAILS_ENV = ENV['RAILS_ENV']
  
  # Try to load the 'redgreen' colorizing gem and use it for test output
  begin
    require 'redgreen'
    TestRunner = Test::Unit::UI::Console::RedGreenTestRunner
  rescue
    TestRunner = Test::Unit::UI::Console::TestRunner
  end
end

# Monkey patch the backtrace filter to include all source files in the plugin
module Test::Unit::Util::BacktraceFilter
  def filter_backtrace(backtrace, prefix = nil)
    backtrace = backtrace.select do |e|
      (e.include? "offline_mirror" or e.start_with? "./") and (!e.include? "Rakefile")
    end
    
    common_prefix = nil
    backtrace.each do |elem|
      next if elem.start_with? "./"
      if common_prefix
        until elem.start_with? common_prefix
          common_prefix.chop!
        end
      else
        common_prefix = String.new(elem)
      end
    end
    
    return backtrace.map do |element|
      if element.start_with? common_prefix && common_prefix.size < element.size
        element[common_prefix.size, element.size]
      elsif element.start_with? "./"
        element[2, element.size]
      else
        element
      end
    end
  end
end

# Run the migrations to set up the in-memory test database
# TODO Improve test speed by only migrating once per testing environment, then just clearing tables as needed
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate") # Migrations for the testing pseudo-Rails app
ActiveRecord::Migrator.migrate("#{File.dirname(__FILE__)}/../lib/migrate/") # Plugin-internal tables

# Runs a given test class immediately; this should be at the end of each test file
def run_test_class(cls)
  lines = []
  saved_stdout = $stdout.clone
  begin
    $stdout = StringIO.new
    TestRunner.run(cls)
    $stdout.close
    lines = $stdout.string.split("\n")
  ensure
    $stdout = saved_stdout
  end
  
  if lines.last.include? ", 0 failures, 0 errors"
    result_line = lines.last
    if result_line =~ /^(.+?)(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors(.+)$/
      result_line = "%s%4u tests, %4u assertions, %4u failures, %4u errors%s" % [$1, $2, $3, $4, $5, $6]
    end
    puts "%-24s %s" % [cls.name + ":", result_line]
  elsif lines.size == 0:
    raise "No output when running test #{cls.name}"
  else
    puts ""
    puts "!"*50
    puts "!!!!!! #{cls.name}"
    lines.each do |line|
      puts "!!! " + line.chomp
    end
    puts "!"*50
    puts ""
  end
end

# Test data setup methods (I don't like fixtures, for many reasons)
class Test::Unit::TestCase
  def create_testing_system_state_and_groups
    if OfflineMirror::app_offline?
      opts = {
        :offline_group_id => 1,
        :current_mirror_version => 1
      }
      OfflineMirror::SystemState::create(opts) or raise "Unable to create offline-mode testing SystemState"
    end
    
    @offline_group = Group.new(:name => "An Offline Group")
    @offline_group.bypass_offline_mirror_readonly_checks
    @offline_group.save!
    raise "Test id mismatch" unless @offline_group.id == OfflineMirror::SystemState::current_mirror_version
    
    @offline_group_data = GroupOwnedRecord.create(:description => "Some Offline Data", :group => @offline_group)
    
    if OfflineMirror::app_online?
      @offline_group.group_offline = true
      
      @online_group = Group.create(:name => "An Online Group") # Will be online by default (tested below)
      @online_group_data = GroupOwnedRecord.create(:description => "Some Online Data", :group => @online_group)
      
      @editable_group = @online_group
      @editable_group_data = @online_group_data
    else  
      @editable_group = @offline_group
      @editable_group_data = @offline_group_data
    end
  end
end

# Convenience methods to create tests that apply to particular environments

def online_test(name, &block)
  common_test(name.to_s + " in online app", &block) unless RAILS_ENV.start_with?("offline")
end

def offline_test(name, &block)
  common_test(name.to_s + " in offline app", &block) if RAILS_ENV.start_with?("offline")
end

def common_test(name, &block)
  define_method ("test_" + name.to_s.gsub(/[^\w ]/, '_').gsub(' ', '_')).to_sym, &block
end