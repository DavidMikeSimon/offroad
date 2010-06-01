class CreateOfflineMirrorTables < ActiveRecord::Migration
  def self.up
    create_table :offline_mirror_system_state do |t|
      t.column :current_mirror_version, :integer, :null => false
    end
    
    create_table :offline_mirror_group_states do |t|
      t.column :app_group_id, :integer, :null => false
      t.column :offline, :boolean, :default => false, :null => false
      t.column :up_mirror_version, :integer, :default => 0, :null => false
      t.column :down_mirror_version, :integer, :default => 0, :null => false
      t.column :last_installer_downloaded_at, :datetime
      t.column :last_installation_at, :datetime
      t.column :last_down_mirror_created_at, :datetime
      t.column :last_down_mirror_loaded_at, :datetime
      t.column :last_up_mirror_created_at, :datetime
      t.column :last_up_mirror_loaded_at, :datetime
      t.column :launcher_version, :integer
      t.column :app_version, :integer
      t.column :last_known_offline_os, :string, :default => "Unknown", :null => false
    end
    add_index :offline_mirror_group_states, :app_group_id, :unique => true
    # This lets us quickly find min(down_mirror_version) for clearing old global record deletions
    add_index :offline_mirror_group_states, :down_mirror_version
    
    create_table :offline_mirror_model_states do |t|
      t.column :app_model_name, :string, :null => false
    end
    add_index :offline_mirror_model_states, :app_model_name, :unique => true
    
    create_table :offline_mirror_sendable_records do |t|
      t.column :model_state_id, :integer, :null => false
      t.column :local_record_id, :integer, :null => false # If 0, record doesn't exist in this app (it has been deleted)
      t.column :remote_record_id, :integer, :null => false # If 0, record might not exist in the remote app (i.e. hasn't yet been created)
      t.column :mirror_version, :integer, :default => 0, :null => false
    end
    # This index is for locating the MirroredRecord model for any given local app record
    add_index :offline_mirror_sendable_records, [:local_record_id, :model_state_id], :unique => true
    # This index is for generating mirror files, where for each model we need to find everything above a given mirror_version
    add_index :offline_mirror_sendable_records, [:model_state_id, :mirror_version]
  end
  
  def self.down
    drop_table :offline_mirror_system_state
    drop_table :offline_mirror_group_states
    drop_table :offline_mirror_model_states
    drop_table :offline_mirror_sendable_records
  end
end
