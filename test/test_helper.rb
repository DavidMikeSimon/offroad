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
      e.include?("offroad") || !(e.include?("/ruby/") || e.include?("/gems/"))
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
    record.bypass_offroad_readonly_checks
    record.save!
    record.reload
  end
end

def force_destroy(*records)
  records.each do |record|
    record.bypass_offroad_readonly_checks
    record.destroy
  end
end

class VirtualTestDatabase
  @@current_database = nil
  @@test_instance = nil
  
  def initialize(prefix, test_class)
    ActiveRecord::Base.connection.clear_query_cache
    
    @prefix = prefix
    @test_instance_vars = {}
    
    if @@current_database != nil
      @@current_database.send(:put_away)
      delete_all_rows
    end
    
    @@test_instance = test_class
    setup
    backup_as_fresh
    @@current_database = self
  end
  
  def bring_forward(test_class, fresh_flag = false)
    ActiveRecord::Base.connection.clear_query_cache
    @@current_database.send(:put_away)
    @@test_instance = test_class
    fresh_flag ? restore_fresh : restore
    @@current_database = self
  end
    
  def delete_all_rows
    tables = ["sqlite_sequence"] + ActiveRecord::Base.connection.tables
    tables.each do |table|
      next if table.start_with?("VIRTUAL_")
      next if table == "schema_migrations"
      ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
    end
  end
  
  protected
  
  def setup
    delete_all_rows
  end
  
  private
  
  def normal_prefix
    "VIRTUAL_normal_#{@prefix}_"
  end
  
  def fresh_prefix
    "VIRTUAL_fresh_#{@prefix}_"
  end
    
  def put_away
    copy_tables("", normal_prefix)
    backup_instance_vars(normal_prefix)
    delete_instance_vars
  end
  
  def backup_as_fresh
    copy_tables("", fresh_prefix)
    backup_instance_vars(fresh_prefix)
  end
  
  def restore
    copy_tables(normal_prefix, "")
    restore_instance_vars(normal_prefix)
  end
  
  def restore_fresh
    copy_tables(fresh_prefix, "")
    restore_instance_vars(fresh_prefix)
  end
  
  def copy_tables(src_prefix, dst_prefix)
    tables = ["sqlite_sequence"] + ActiveRecord::Base.connection.tables
    tables.each do |src_table|
      next if src_table.end_with?("schema_migrations")
      next unless src_table.start_with?(src_prefix)
      next if dst_prefix != "" && src_table.start_with?(dst_prefix)
      dst_table = dst_prefix + src_table[(src_prefix.size)..(src_table.size)]
      next if src_table.start_with?("VIRTUAL") && dst_table.start_with?("VIRTUAL")
      if tables.include?(dst_table)
        ActiveRecord::Base.connection.execute "DELETE FROM #{dst_table}"
        ActiveRecord::Base.connection.execute "INSERT INTO #{dst_table} SELECT * FROM #{src_table}"
      else
        ActiveRecord::Base.connection.execute "CREATE TABLE #{dst_table} AS SELECT * FROM #{src_table}"
      end
    end
  end
  
  def backup_instance_vars(key)
    @test_instance_vars ||= {}
    @test_instance_vars[key] = {}
    @@test_instance.instance_variables.each do |varname|
      next unless @test_instance_var_names.has_key?(varname)
      value = @@test_instance.instance_variable_get(varname.to_sym)
      next unless value
      @test_instance_vars[key][varname] = value.dup
    end
  end
  
  def restore_instance_vars(key)
    delete_instance_vars
    @test_instance_vars[key].each_pair do |varname, value|
      restored_val = nil
      if value.is_a?(ActiveRecord::Base)
        if !value.destroyed? && (value.changed? || value.new_record?)
          restored_val = value.class.find(value.id)
        else
          restored_val = value
        end
      else
        restored_val = value.dup
      end
      
      # Using find_by_id so that if the record was destroyed earlier in the test, RecordNotFound isn't raised here
      restored_val = value.is_a?(ActiveRecord::Base) ? value.class.find_by_id(value.id) : value.dup
      
      @@test_instance.instance_variable_set(varname.to_sym, restored_val)
    end
  end
  
  def delete_instance_vars
    @@test_instance.instance_variables.each do |varname|
      next unless @test_instance_var_names.has_key?(varname)
      @@test_instance.instance_variable_set(varname.to_sym, nil)
    end
  end
  
  def setup_ivar(key, value)
    @test_instance_var_names ||= {}
    @test_instance_var_names[key.to_s] = true
    @@test_instance.instance_variable_set(key, value)
  end
end

class OnlineTestDatabase < VirtualTestDatabase
  def initialize(test_class)
    super("online", test_class)
  end
  
  def self.initial_mirror_data
    @@initial_mirror_data
  end
  
  protected
  
  def setup
    super
    
    unused_offline_group = Group.create(:name => "Unused Offline Group")
    unused_online_group = Group.create(:name => "Unused Online Group")
    unused_offline_group.group_offline = true
    
    offline_group = Group.create(:name => "An Offline Group")
    online_group = Group.create(:name => "An Online Group")
    offline_group.group_offline = true
    setup_ivar(:@offline_group, offline_group)
    setup_ivar(:@online_group, online_group)
    
    offline_data = GroupOwnedRecord.new( :description => "Sam", :group => offline_group)
    online_data = GroupOwnedRecord.new(:description => "Max", :group => online_group)
    force_save_and_reload(offline_data, online_data)
    setup_ivar(:@offline_group_data, offline_data)
    setup_ivar(:@online_group_data, online_data)

    indirect_offline_data = SubRecord.new( :description => "Boris", :group_owned_record => offline_data)
    indirect_online_data = SubRecord.new( :description => "Natasha", :group_owned_record => online_data)
    force_save_and_reload(indirect_offline_data, indirect_online_data)
    setup_ivar(:@offline_indirect_data, indirect_offline_data)
    setup_ivar(:@online_indirect_data, indirect_online_data)
    
    setup_ivar(:@editable_group, online_group)
    setup_ivar(:@editable_group_data, online_data)
    setup_ivar(:@editable_indirect_data, indirect_online_data)
    
    @@initial_mirror_data ||= Offroad::MirrorData.new(offline_group, :initial_mode => true).write_downwards_data
  end
end

class OfflineTestDatabase < VirtualTestDatabase
  def initialize(test_class)
    super("offline", test_class)
  end
  
  protected
  
  def setup
    super
    
    Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(
      OnlineTestDatabase::initial_mirror_data
    )
    
    offline_group = Group.first
    offline_data = GroupOwnedRecord.first
    offline_indirect_data = SubRecord.first
    
    setup_ivar(:@offline_group, offline_group)
    setup_ivar(:@offline_group_data, offline_data)
    setup_ivar(:@offline_indirect_data, offline_indirect_data)
    
    setup_ivar(:@editable_group, offline_group)
    setup_ivar(:@editable_group_data, offline_data)
    setup_ivar(:@editable_indirect_data, offline_indirect_data)
  end
end

class Test::Unit::TestCase
  @@online_database = nil
  @@offline_database = nil
  
  def setup
    unless ActiveRecord::Base.connection.table_exists?("schema_migrations")
      # FIXME : Figure out why ActionController::TestCase keeps on deleting all the tables before each method
      
      # First time the setup method has ran, create our test databases
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate") # Migrations for the testing pseudo-app
      ActiveRecord::Migrator.migrate("#{File.dirname(__FILE__)}/../lib/migrate/") # Plugin-internal tables
      
      Offroad::config_app_online(true)
      @@online_database = OnlineTestDatabase.new(self)
      
      Offroad::config_app_online(false)
      @@offline_database = OfflineTestDatabase.new(self)
      
      Offroad::config_app_online(nil)
    end
  end
  
  def in_online_app(fresh_flag = false, delete_all_rows = false, &block)
    begin
      Offroad::config_app_online(true)
      @@online_database.bring_forward(self, fresh_flag)
      if delete_all_rows
        @@online_database.delete_all_rows
      end
      instance_eval &block
    ensure
      Offroad::config_app_online(nil)
    end
  end
  
  def in_offline_app(fresh_flag = false, delete_all_rows = false, &block)
    begin
      Offroad::config_app_online(false)
      @@offline_database.bring_forward(self, fresh_flag)
      if delete_all_rows
        @@offline_database.delete_all_rows
      end
      instance_eval &block
    ensure
      Offroad::config_app_online(nil)
    end
  end
  
  def restore_all_from_fresh
    @@offline_database.bring_forward(self, true)
    @@online_database.bring_forward(self, true)
  end
end

def define_wrapped_test(name, wrapper_proc, block)
  method_name = "test_" + name.to_s.gsub(/[^\w ]/, '_').gsub(' ', '_')
  define_method method_name.to_sym, &block
  if wrapper_proc
    define_method "wrapped_#{method_name}".to_sym do
      wrapper_proc.call(self) { send "unwrapped_#{method_name}".to_sym }
    end
    alias_method "unwrapped_#{method_name}".to_sym, method_name.to_sym
    alias_method method_name.to_sym, "wrapped_#{method_name}".to_sym
  end
end

# Convenience methods to create tests that apply to particular environments or situations

# Test that should be run in the online environment
def online_test(name, &block)
  wrapper = Proc.new do |t|
    t.in_online_app(true, &block)
  end
  
  define_wrapped_test("ONLINE #{name}", wrapper, block)
end

# Test that is ran in the online environment, but with no preset records 
def empty_online_test(name, &block)
  wrapper = Proc.new do |t|
    t.in_online_app(false, true, &block)
  end
  
  define_wrapped_test("EMPTY ONLINE #{name}", wrapper, block)
end

# Test that should be run in the offline environment
def offline_test(name, &block)
  wrapper = Proc.new do |t|
    t.in_offline_app(true, &block)
  end
  
  define_wrapped_test("OFFLINE #{name}", wrapper, block)
end

# Test that should be run twice, once online and once offline
def double_test(name, &block)
  online_test(name, &block)
  offline_test(name, &block)
end

# Test that shouldn't care what environment it is started in
def agnostic_test(name, &block)
  define_wrapped_test("AGNOSTIC #{name}", nil, block)
end

# Test that involves both environments (within test, use in_online_app and in_offline_app)
def cross_test(name, &block)
  wrapper = Proc.new do |t|
    t.restore_all_from_fresh
    t.instance_eval &block
  end
  
  define_wrapped_test("CROSS #{name}", wrapper, block)
end
