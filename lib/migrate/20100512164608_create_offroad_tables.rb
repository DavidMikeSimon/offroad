class CreateOffroadTables < ActiveRecord::Migration
  def self.up
    create_table :offroad_system_state do |t|
      t.column :current_mirror_version, :integer
    end
    
    create_table :offroad_group_states do |t|
      t.column :app_group_id, :integer, :null => false
      
      # This is used to allow group_owned records to be destroyed when their parent is.
      # Without this, groups with :dependent => :destroy would not be allowed on the online app.
      # This is NOT used to propogate group deletion through mirror files.
      t.column :group_being_destroyed, :boolean, :default => false, :null => false

      # If a group is locked (which can only occur offline) then its records cannot be altered anymore.
      # If a locked group is sent up to the online system, then after loading it the online system puts that group back
      # online.
      t.column :group_locked, :boolean, :default => false, :null => false
      
      # On both the online and offline systems, these are the latest data versions remote side is known to have
      t.column :confirmed_group_data_version, :integer, :null => false
      t.column :confirmed_global_data_version, :integer, :null => false
      
      t.column :last_installer_downloaded_at, :datetime
      t.column :last_installation_at, :datetime
      t.column :last_down_mirror_created_at, :datetime
      t.column :last_down_mirror_loaded_at, :datetime
      t.column :last_up_mirror_created_at, :datetime
      t.column :last_up_mirror_loaded_at, :datetime
      t.column :launcher_version, :integer
      t.column :app_version, :integer
      t.column :operating_system, :string, :default => "Unknown", :null => false
    end
    add_index :offroad_group_states, :app_group_id, :unique => true
    # This lets us quickly find min(global_mirror_version) for clearing old deleted global record SRSes
    add_index :offroad_group_states, :confirmed_global_data_version
    
    create_table :offroad_model_states do |t|
      t.column :app_model_name, :string, :null => false
    end
    add_index :offroad_model_states, :app_model_name, :unique => true
    
    create_table :offroad_sendable_record_states do |t|
      t.column :model_state_id, :integer, :null => false
      t.column :local_record_id, :integer, :null => false
      t.column :mirror_version, :integer, :default => 0, :null => false
      t.column :deleted, :boolean, :default => false, :null => false
    end
    # This index is for locating the SRS for any given local app record
    add_index :offroad_sendable_record_states, [:local_record_id, :model_state_id], :unique => true
    # This index is for generating mirror files: for a given model need to find everything above a given mirror_version
    add_index :offroad_sendable_record_states, [:model_state_id, :deleted, :mirror_version]
    
    create_table :offroad_received_record_states do |t|
      t.column :model_state_id, :integer, :null => false
      t.column :group_state_id, :integer, :default => 0, :null => false # If 0, is a global record
      t.column :local_record_id, :integer, :null => false
      t.column :remote_record_id, :integer, :null => false
    end
    add_index :offroad_received_record_states, [:model_state_id, :group_state_id, :remote_record_id], :unique => true
    # TODO: Perhaps index below can be removed; it enforces data integrity, but isn't actually used for lookups
    add_index :offroad_received_record_states, [:model_state_id, :local_record_id], :unique => true
  end
  
  def self.down
    drop_table :offroad_system_state
    drop_table :offroad_group_states
    drop_table :offroad_model_states
    drop_table :offroad_sendable_record_states
    drop_table :offroad_received_record_states
  end
end
