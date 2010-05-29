# desc "Explaining what the task does"
# task :offline_mirror do
#   # Task goes here
# end

namespace :offline_mirror do
	def set_migration_verbosity
		ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
	end
	
	def dump_schema
		Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
	end

	def install_template_files(target_dir_array, filenames)
		filenames.each do |filename|
			src_path = File.join(File.dirname(__FILE__), "..", "templates", filename)
			tgt_path = File.join([RAILS_ROOT] + target_dir_array + [filename])
			cp src_path, tgt_path
		end
	end
	
	def setup_mirroring_for_model_data(model)
		model.find_each do |rec|
			OfflineMirror::SendableRecord::note_record_created_or_updated(model, rec.id)
		end
	end
	
	desc "Creates the internal tables used by offline_mirror"
	task :create_tables => :environment do
		set_migration_verbosity
		ActiveRecord::Migrator.migrate("vendor/plugins/offline_mirror/lib/migrate/", nil)
		dump_schema
	end
	
	desc "Drops the internal tables used by offline_mirror"
	task :drop_tables => :environment do
		set_migration_verbosity
		ActiveRecord::Migrator.migrate("vendor/plugins/offline_mirror/lib/migrate/", 0)
		dump_schema
	end
	
	desc "Installs or reinstalls the default offline_mirror configuration files"
	task :install_conf => :environment do
		install_template_files(["config"], ["offline_mirror.yml", "offline_database.yml", "offline_test_database.yml"])
		install_template_files(["config", "environments"], ["offline.rb", "offline_test.rb"])
	end
	
	desc "Initializes offline_mirror's internal tables to follow any records already existing in acts_as_mirrored_offline models"
	task :import_existing_data => :environment do
		if OfflineMirror::app_online?
			# Setup mirroring for *global* records
			OfflineMirror::global_data_models.each do |name, cls|
				setup_mirroring_for_model_data cls
			end
		else
			# Setup mirroring for *group* records
			OfflineMirror::group_data_models.each do |name, cls|
				setup_mirroring_for_model_data cls
			end
		end
	end
end
