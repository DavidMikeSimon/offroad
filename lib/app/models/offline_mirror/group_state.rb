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
        last_known_offline_os = RUBY_PLATFORM
      end
    end
    
    def self.safe_to_load_from_cargo_stream?
      true
    end
    
    def self.note_group_destroyed(group)
      rec = find_by_app_group_id(group.id)
      rec.destroy
    end
    
    def online?
      not offline?
    end
    
    private
    
    def self.valid_group_record?(rec)
      rec.class.respond_to?(:offline_mirror_group_base?) && rec.class.offline_mirror_group_base?
    end
  end
end