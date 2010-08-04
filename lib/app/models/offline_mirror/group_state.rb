module OfflineMirror
  private
  
  class GroupState < ActiveRecord::Base
    set_table_name "offline_mirror_group_states"
    
    validates_presence_of :app_group_id
    
    def self.safe_to_load_from_cargo_stream?
      true
    end
    
    def self.note_group_destroyed(group)
      rec = find_by_app_group_id(group.id)
      rec.destroy
    end
    
    def self.find_or_create_by_group(obj, opts = {})
      if obj.new_record?
        raise DataError.new("Cannot build group state for unsaved group records")
      end
      
      unless obj.class.offline_mirror_mode == :group_base
        raise ModelError.new("Passed object is not of a group_base_model")
      end
      
      rec = find_or_initialize_by_app_group_id(obj.id, opts)
      if OfflineMirror::app_offline?
        # FIXME : Fill in last_installation_at, launcher_version, app_version
        rec.last_known_offline_os = RUBY_PLATFORM
        rec.offline = true
      end
      rec.save!
      return rec
    end
    
    def online?
      not offline?
    end
  end
end