# desc "Explaining what the task does"
# task :offroad do
#   # Task goes here
# end

namespace :offroad do
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
      Offroad::SendableRecordState::note_record_created_or_updated(model, rec.id)
    end
  end
  
  desc "Creates the internal tables used by offroad"
  task :create_tables => :environment do
    set_migration_verbosity
    ActiveRecord::Migrator.migrate("vendor/plugins/offroad/lib/migrate/", nil)
    dump_schema
  end
  
  desc "Drops the internal tables used by offroad"
  task :drop_tables => :environment do
    set_migration_verbosity
    ActiveRecord::Migrator.migrate("vendor/plugins/offroad/lib/migrate/", 0)
    dump_schema
  end
  
  desc "Installs or reinstalls the default offroad configuration files"
  task :install_conf do
    install_template_files(["config"], ["offroad.yml", "offline_database.yml", "offline_test_database.yml"])
    install_template_files(["config", "environments"], ["offline.rb", "offline_test.rb"])
  end
  
  desc "Initializes offroad's internal tables to follow any records already existing in acts_as_offroadable models"
  task :import_existing_data => :environment do
    if Offroad::app_online?
      # Setup mirroring for *global* records
      Offroad::global_data_models.each do |name, cls|
        setup_mirroring_for_model_data cls
      end
    else
      # Setup mirroring for *group* records
      Offroad::group_data_models.each do |name, cls|
        setup_mirroring_for_model_data cls
      end
    end
  end
end
