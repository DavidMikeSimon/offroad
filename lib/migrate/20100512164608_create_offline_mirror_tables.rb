class CreateOfflineMirrorTables < ActiveRecord::Migration
	def self.up
		create_table :offline_mirror_group_states, :force => true do |t|
			t.column :app_group_id, :integer
			t.column :offline, :boolean
			t.column :last_installer_download_at, :datetime
			t.column :last_down_mirror_at, :datetime
			t.column :last_up_mirror_at, :datetime
			t.column :launcher_version, :datetime
			t.column :app_version, :datetime
			t.column :last_known_os, :string
		end
		
		create_table :offline_mirror_model_states, :force => true do |t|
			t.column :app_model_name, :string
			t.column :version_columns, :string # FIXME : Is this the proper column type for JSON'd array of strings? And, is that how I should do this?
		end
		
		create_table :offline_mirror_group_model_pairings, :force => true do |t|
			t.column :group_state_id, :integer
			t.column :model_state_id, :integer
		end
		
		create_table :offline_mirror_mirrored_records, :force => true do |t|
			t.column :group_model_pairing_id, :integer
			t.column :offline_app_record_id, :integer
			t.column :online_app_record_id, :integer
			t.column :version, :string # FIXME : Is this the proper column type for JSON'd array of strings? And, is that how I should do this?
		end
	end
	
	def self.down
		drop_table :offline_mirror_group_states
		drop_table :offline_mirror_model_states
		drop_table :offline_mirror_group_model_pairings
		drop_table :offline_mirror_mirrored_records
	end
end
