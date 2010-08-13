module OfflineMirror
  private
  
  class GroupState < ActiveRecord::Base
    set_table_name "offline_mirror_group_states"
    
    validates_presence_of :app_group_id
    
    def validate
      app_group = OfflineMirror::group_base_model.find_by_id(app_group_id)
      errors.add_to_base "Cannot find associated app group record" unless app_group
    end
    
    has_many :received_record_states, :class_name => "::OfflineMirror::ReceivedRecordState", :dependent => :delete_all
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :app_group_id => valid_group_record?(group) ? group.id : 0
    } } }
    
    def before_create
      if OfflineMirror::app_offline?
        # FIXME : Fill in last_installation_at, launcher_version, app_version, etc
        self.operating_system ||= RUBY_PLATFORM
      end
      
      # When first setting a group offline, assume it will start out with at least current global data.
      # It should, since that's the earlier version which might be loaded into the initial down mirror file.
      self.global_data_version = OfflineMirror::app_online? ? SystemState::global_data_version : 1
    end
    
    def setup_as_new_offline_group!
      raise PluginError.new("Cannot setup new offline group in online app") unless OfflineMirror::app_offline?
      self.group_data_version = 1
      save!
    end
    
    def update_from_remote_group_state!(remote_gs)
      online_owned_columns = [
        'global_data_version',
        'last_installer_downloaded_at',
        'last_down_mirror_created_at',
        'last_up_mirror_loaded_at'
      ]
      
      if OfflineMirror::app_offline?
        online_owned_columns.each do |col|
          self.send("#{col}=", remote_gs.send(col))
        end
      else
        self.class.column_names.each do |col|
          self.send("#{col}=", remote_gs.send(col)) unless online_owned_columns.include?(col)
        end
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
      rec.class.respond_to?(:offline_mirror_group_base?) && rec.class.offline_mirror_group_base?
    end
  end
end