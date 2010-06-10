module OfflineMirror
  private
  
  class GroupState < ActiveRecord::Base
    set_table_name "offline_mirror_group_states"
    
    has_many :group_model_pairings
    
    validates_presence_of :app_group_id
    
    def self.exists_by_app_group_id?(local_id)
      exists?(:app_group_id => local_id)
    end
    
    def self.find_or_create_by_group(obj, opts = {})
      if obj.new_record?
        raise OfflineMirror::DataError.new("Cannot build group state for unsaved group records")
      end
      
      unless obj.class.offline_mirror_mode == :group_base
        raise OfflineMirror::ModelError.new("Passed object is not of a group_base_model")
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