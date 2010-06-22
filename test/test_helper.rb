# Load the Rails environment
require "#{File.dirname(__FILE__)}/app_root/config/environment"
require 'test/unit'
require 'test/unit/ui/console/testrunner'
require 'test/unit/util/backtracefilter'

silence_warnings do
  # Undo changes to RAILS_ENV made by Rails' test_help
  RAILS_ENV = ENV['RAILS_ENV']
end

begin
  require 'redgreen'
  TestRunner = Test::Unit::UI::Console::RedGreenTestRunner
rescue
  TestRunner = Test::Unit::UI::Console::TestRunner
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
      elsif element.start_with?(Dir.getwd)
        element[Dir.getwd.size+1, element.size]
      else
        element
      end
    end
  end
end

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

# Test data setup (I don't like rails' fixtures, for several reasons)
class Test::Unit::TestCase
  @@database_migrated = false
  @@fixture = {}
  
  def self.initialize_database
    unless @@database_migrated
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate") # Migrations for the testing pseudo-app
      ActiveRecord::Migrator.migrate("#{File.dirname(__FILE__)}/../lib/migrate/") # Plugin-internal tables
      @@database_migrated = true
    end
    
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations"
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
      ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table}'")
    end
    
    opts = { :current_mirror_version => 1 }
    opts[:offline_group_id] = 1 if OfflineMirror::app_offline?
    OfflineMirror::SystemState::create(opts) or raise "Unable to create testing SystemState"
    
    @@fixture[:offline_group] = Group.new(:name => "An Offline Group")
    force_save_and_reload(@@fixture[:offline_group])
    raise "Test id mismatch" unless @@fixture[:offline_group].id == OfflineMirror::SystemState::current_mirror_version
    
    @@fixture[:offline_group_data] = GroupOwnedRecord.new(
         :description => "Some Offline Data", :group => @@fixture[:offline_group])
    force_save_and_reload(@@fixture[:offline_group_data])
    
    if OfflineMirror::app_online?
      @@fixture[:offline_group].group_offline = true # In offline mode, the group will be offline by default
      
      @@fixture[:online_group] = Group.new(:name => "An Online Group") # Will be online by default (tested below)
      force_save_and_reload(@@fixture[:online_group])
      @@fixture[:online_group_data] = GroupOwnedRecord.new(:description => "Some Online Data", :group => @@fixture[:online_group])
      force_save_and_reload(@@fixture[:online_group_data])
      
      @@fixture[:editable_group] = @@fixture[:online_group]
      @@fixture[:editable_group_data] = @@fixture[:online_group_data]
    else  
      @@fixture[:editable_group] = @@fixture[:offline_group]
      @@fixture[:editable_group_data] = @@fixture[:offline_group_data]
    end
  end
  
  def self.force_save_and_reload(*records)
    records.each do |record|
      record.bypass_offline_mirror_readonly_checks
      record.save!
      record.reload
    end
  end
  
  def force_save_and_reload(*records)
    self.class.force_save_and_reload(*records)
  end
  
  def self.force_destroy(*records)
    records.each do |record|
      record.bypass_offline_mirror_readonly_checks
      record.destroy
    end
  end
  
  def force_destroy(*records)
    self.class.force_destroy(*records)
  end
  
  def setup
    self.class.initialize_database
    
    @@fixture.each_pair do |key, value|
      instance_variable_set("@#{key.to_s}".to_sym, value)
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