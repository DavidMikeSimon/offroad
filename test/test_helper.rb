ENV['RAILS_ENV'] = 'test'

prev_dir = Dir.getwd
begin
  Dir.chdir("#{File.dirname(__FILE__)}/..")
  
  begin
    # Used when running plugin files directly
    require "#{File.dirname(__FILE__)}/app_root/config/environment"
  rescue LoadError
    # This is needed for root-level rake task test:plugins
    require "app_root/config/environment"
  end
ensure
  Dir.chdir(prev_dir)
end

require 'rubygems'
require 'test/unit/util/backtracefilter'
require 'test_help'

# Try to load the redgreen test console outputter, if it's available
begin
  require 'redgreen'
rescue LoadError
end

# Monkey patch the backtrace filter to include source files in the plugin
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

def force_save_and_reload(*records)
  records.each do |record|
    record.bypass_offline_mirror_readonly_checks
    record.save!
    record.reload
  end
end

def force_destroy(*records)
  records.each do |record|
    record.bypass_offline_mirror_readonly_checks
    record.destroy
  end
end

class Test::Unit::TestCase
  @@database_migrated = false
  @@fixture = {}

  # Test data setup (I don't like rails' fixtures, for several reasons)
  def self.initialize_database
    unless @@database_migrated
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate") # Migrations for the testing pseudo-app
      ActiveRecord::Migrator.migrate("#{File.dirname(__FILE__)}/../lib/migrate/") # Plugin-internal tables
      @@database_migrated = true
    end
    
    OfflineMirror::config_app_online(true)
    
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations"
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
      ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table}'")
    end
    
    OfflineMirror::SystemState::create(
      :current_mirror_version => 1,
      :offline_group_id => 1
    ) or raise "Unable to create testing SystemState"
    
    @@fixture[:offline_group] = Group.new(:name => "An Offline Group")
    @@fixture[:online_group] = Group.new(:name => "An Online Group")
    force_save_and_reload(@@fixture[:offline_group], @@fixture[:online_group])
    @@fixture[:offline_group].group_offline = true
    raise "Test id mismatch" unless @@fixture[:offline_group].id == OfflineMirror::SystemState::offline_group_id
    
    @@fixture[:offline_group_data] = GroupOwnedRecord.new( :description => "Sam", :group => @@fixture[:offline_group])
    @@fixture[:online_group_data] = GroupOwnedRecord.new(:description => "Max", :group => @@fixture[:online_group])
    force_save_and_reload(@@fixture[:offline_group_data], @@fixture[:online_group_data])
      
    @@fixture[:editable_group] = @@fixture[:online_group]
    @@fixture[:editable_group_data] = @@fixture[:online_group_data]
  end
  
  def setup
    self.class.initialize_database
    
    @@fixture.each_pair do |key, value|
      instance_variable_set("@#{key.to_s}".to_sym, value)
    end
  end
end

def define_wrapped_test(name, before_proc, after_proc, block)
  method_name = "test_" + name.to_s.gsub(/[^\w ]/, '_').gsub(' ', '_')
  define_method method_name.to_sym, &block
  define_method "wrapped_#{method_name}".to_sym do
    begin
      before_proc.call(self) if before_proc
      send "unwrapped_#{method_name}".to_sym
    ensure
      after_proc.call(self) if after_proc
    end
  end
  alias_method "unwrapped_#{method_name}".to_sym, method_name.to_sym
  alias_method method_name.to_sym, "wrapped_#{method_name}".to_sym
end

# Convenience methods to create tests that apply to particular environments

# Test that should be run in the online environment
def online_test(name, &block)
  before = Proc.new do
    OfflineMirror::config_app_online(true)
  end
  
  define_wrapped_test("ONLINE #{name}", before, nil, block)
end

# Test that should be run in the offline environment
def offline_test(name, &block)
  before = Proc.new do |t|
    OfflineMirror::config_app_online(false)
    t.instance_variable_set(:@editable_group, t.instance_variable_get(:@offline_group))
    t.instance_variable_set(:@editable_group_data, t.instance_variable_get(:@offline_group_data))
  end
  
  define_wrapped_test("OFFLINE #{name}", before, nil, block)
end

# Test that should be run in both environments
def common_test(name, &block)
  online_test(name, &block)
  offline_test(name, &block)
end

# Test that shouldn't care what environment it is started in
def agnostic_test(name, &block)
  before = Proc.new do |t|
    OfflineMirror::config_app_online(nil)
  end
  
  define_wrapped_test("AGNOSTIC #{name}", before, nil, block)
end