# desc "Explaining what the task does"
# task :offline_bridge do
#   # Task goes here
# end

namespace :offline_bridge do
	def set_migration_verbosity
		ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
	end

	def dump_schema
		Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
	end

	desc "Creates the internal tables used by offline_bridge"
	task :create_tables => :environment do
		set_migration_verbosity
		ActiveRecord::Migrator.migrate("vendor/plugins/offline_bridge/lib/migrate/", nil)
		dump_schema
	end

	desc "Drops the internal tables used by offline_bridge"
	task :drop_tables => :environment do
		set_migration_verbosity
		ActiveRecord::Migrator.migrate("vendor/plugins/offline_bridge/lib/migrate/", 0)
		dump_schema
	end

	desc "Installs or reinstalls the default offline_bridge configuration files"
	task :install_conf => :environment do
		cp File.join(File.dirname(__FILE__), "..", "templates", "offline_bridge.yml"), File.join(RAILS_ROOT, "config", "offline_bridge.yml")
		cp File.join(File.dirname(__FILE__), "..", "templates", "offline_database.yml"), File.join(RAILS_ROOT, "config", "offline_database.yml")
		cp File.join(File.dirname(__FILE__), "..", "templates", "offline.rb"), File.join(RAILS_ROOT, "config", "environments", "offline.rb")
	end
end
