module Offroad
  private
  
  class GroupState < ActiveRecord::Base
    set_table_name "offroad_group_states"
    
    validates_presence_of :app_group_id
    
    def validate
      app_group = Offroad::group_base_model.find_by_id(app_group_id)
      errors.add_to_base "Cannot find associated app group record" unless app_group
    end
    
    has_many :received_record_states, :class_name => "::Offroad::ReceivedRecordState", :dependent => :delete_all
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :app_group_id => valid_group_record?(group) ? group.id : 0
    } } }
    
    def before_create
      if Offroad::app_offline?
        # FIXME : Fill in last_installation_at, launcher_version, app_version, etc
        self.operating_system ||= RUBY_PLATFORM
      end
      
      self.confirmed_group_data_version ||= 1
      
      # When first setting a group offline at online app, assume it will start out with at least current global data.
      # It should, since that's the earliest version that could be loaded into the initial down mirror file.
      self.confirmed_global_data_version ||= Offroad::app_online? ? SystemState::current_mirror_version : 1
    end
    
    def update_from_remote_group_state!(remote_gs)
      versioning_columns = [
        'confirmed_global_data_version',
        'confirmed_group_data_version'
      ]
      
      online_owned_columns = [
        'last_installer_downloaded_at',
        'last_down_mirror_created_at',
        'last_up_mirror_loaded_at'
      ]
      
      offline_owned_columns = [
        'last_installation_at',
        'last_down_mirror_loaded_at',
        'last_up_mirror_created_at',
        'launcher_version',
        'app_version',
        'operating_system'
      ]
      
      # Copy in values from columns owned by the remote environment that created remote_gs
      (Offroad::app_offline? ? online_owned_columns : offline_owned_columns).each do |col|
        self.send("#{col}=", remote_gs.send(col))
      end
      
      # If the remote side says they have a newer version of something than we currently think they have, update
      versioning_columns.each do |col|
        self.send("#{col}=", [self.send(col), remote_gs.send(col)].max)
      end
      
      save!
    end
    
    def self.safe_to_load_from_cargo_stream?
      true
    end
    
    def self.note_group_destroyed(group)
      rec = find_by_app_group_id(group.id)
      rec.destroy
    end
    
    private
    
    def self.valid_group_record?(rec)
      rec.class.respond_to?(:offroad_group_base?) && rec.class.offroad_group_base?
    end
  end
end
