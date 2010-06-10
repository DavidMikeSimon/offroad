module OfflineMirror
  private
  
  class SendableRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_sendable_record_states"
    
    belongs_to :model_state
    validates_presence_of :model_state
    
    def self.note_record_destroyed(record)
      mark_record_changes(record) do |rec|
        rec.local_record_id = 0
      end
    end
    
    def self.note_record_created_or_updated(record)
      mark_record_changes(record)
    end
    
    def self.find_or_initialize_by_record(rec)
      unless rec.class.acts_as_mirrored_offline?
        raise OfflineMirror::ModelError
      end
      
      model_state_id = OfflineMirror::ModelState::find_or_create_by_model(rec.class).id
      
      # If this record is itself a group record, then create its GroupState entry if it doesn't already exist
      if rec.class.offline_mirror_mode == :group_base && !OfflineMirror::GroupState::exists_by_app_group_id?(rec.id)
        OfflineMirror::GroupState::find_or_create_by_group rec
      end
      
      return find_or_initialize_by_model_state_id_and_local_record_id(
        :model_state_id => model_state_id,
        :local_record_id => rec.id,
        :remote_record_id => 0
      )
    end
    
    private
    
    def self.mark_record_changes(record)
      unless record.class.acts_as_mirrored_offline?
        raise OfflineMirror::ModelError("Unable to mark changes to unmirrored record")
      end
      
      transaction do
        rec_state = find_or_initialize_by_record(record)
        rec_state.lock!
        yield(rec_state) if block_given?
        rec_state.mirror_version = OfflineMirror::SystemState::current_mirror_version
        rec_state.save!
      end
    end
    
  end
end
