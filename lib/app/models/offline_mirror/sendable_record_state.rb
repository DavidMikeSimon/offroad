module OfflineMirror
  private
  
  class SendableRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_sendable_record_states"
    
    belongs_to :model_state
    validates_presence_of :model_state
    
    def self.note_record_destroyed(model, local_id)
      mark_record_changes(model, local_id) do |rec|
        rec.local_record_id = 0
      end
    end
    
    def self.note_record_created_or_updated(model, local_id)
      mark_record_changes(model, local_id)
    end
    
    def self.find_or_initialize_by_model_and_id(model, local_id)
      model_state_id = OfflineMirror::ModelState::find_or_create_by_model(model).id
      
      # If this record is itself a group record, then create its GroupState entry if it doesn't already exist
      if model.offline_mirror_mode == :group_base && !OfflineMirror::GroupState::exists_by_app_group_id?(local_id)
        OfflineMirror::GroupState::find_or_create_by_group model.find(local_id)
      end
      
      return find_or_initialize_by_model_state_id_and_local_record_id(
        :model_state_id => model_state_id,
        :local_record_id => local_id,
        :remote_record_id => 0
      )
    end
    
    def self.find_by_model_and_id(model, local_id)
      model_state = OfflineMirror::ModelState::find_by_model(model)
      return nil unless model_state
      return find_by_model_state_id_and_local_record_id(model_state.id, local_id)
    end
    
    def self.find_or_initialize_by_record(rec)
      find_or_initialize_by_model_and_id(rec.class, rec.id)
    end
    
    def self.find_by_record(rec)
      find_by_model_and_id(rec.class, rec.id)
    end
    
    private
    
    def self.mark_record_changes(model, local_id)
      raise OfflineMirror::ModelError("Unable to mark changes unmirrored record") unless model.acts_as_mirrored_offline?
      transaction do
        rec = find_or_initialize_by_model_and_id(model, local_id)
        rec.lock!
        yield(rec) if block_given?
        rec.mirror_version = OfflineMirror::SystemState::current_mirror_version
        rec.save!
      end
    end
    
  end
end
