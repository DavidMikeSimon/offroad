# Load the Rails environment
require "#{File.dirname(__FILE__)}/app_root/config/environment"
require 'test_help'
require 'test/unit'
require 'test/unit/ui/console/testrunner'

silence_warnings do
  # Undo changes to RAILS_ENV made by the prior requires
  RAILS_ENV = ENV['RAILS_ENV']
  
  begin
    # Try to load the 'redgreen' gem and use it for test output
    require 'redgreen'
    TestRunner = Test::Unit::UI::Console::RedGreenTestRunner
  rescue
    # Stick with the regular TestRunner
    TestRunner = Test::Unit::UI::Console::TestRunner
  end
end


# Run the migrations to set up the in-memory test database
# TODO Improve test speed by only migrating once per testing environment
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate") # Migrations for the testing pseudo-Rails app
ActiveRecord::Migrator.migrate("#{File.dirname(__FILE__)}/../lib/migrate/") # Plugin-internal tables

# Runs a given test class immediately; this should be at the end of each test file
def run_test_class(cls)
  TestRunner.run(cls)
end

# Convenience methods to create tests that apply to online-mode only, offline-mode only, or to both

def online_test(name, &block)
  common_test(name, &block) unless RAILS_ENV.start_with?("offline")
end

def offline_test(name, &block)
  common_test(name, &block) if RAILS_ENV.start_with?("offline")
end

def common_test(name, &block)
  define_method ("test_" + name.to_s).to_sym, &block
end
