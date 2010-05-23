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
			t.column :last_installer_download_at, :datetime
			t.column :last_installation_at, :datetime
			t.column :last_down_mirror_downloaded_at, :datetime
			t.column :last_down_mirror_loaded_at, :datetime
			t.column :last_up_mirror_downloaded_at, :datetime
			t.column :last_up_mirror_loaded_at, :datetime
			t.column :launcher_version, :integer, :default => 0, :null => false
			t.column :app_version, :integer, :default => 0, :null => false
			t.column :last_known_offline_os, :string, :default => "Unknown", :null => false
		end
		
		create_table :offline_mirror_model_states do |t|
			t.column :app_model_name, :string, :null => false
		end
		
		create_table :offline_mirror_group_model_pairings do |t|
			t.column :group_state_id, :integer
			t.column :model_state_id, :integer, :null => false
		end
		
		create_table :offline_mirror_mirrored_records do |t|
			t.column :group_model_pairing_id, :integer, :null => false
			t.column :offline_app_record_id, :integer, :null => false
			t.column :online_app_record_id, :integer, :null => false
			t.column :mirror_version, :integer, :default => 0, :null => false
		end
	end
	
	def self.down
		drop_table :offline_mirror_system_state
		drop_table :offline_mirror_group_states
		drop_table :offline_mirror_model_states
		drop_table :offline_mirror_group_model_pairings
		drop_table :offline_mirror_mirrored_records
	end
end
