module OfflineMirror
  private
  
  class SendableRecord < ActiveRecord::Base
    set_table_name "offline_mirror_sendable_records"
    
    belongs_to :group_state
    belongs_to :model_state
    
    def self.note_record_destroyed(model, local_id)
      rec = find_or_initialize_by_model_and_id(model, local_id)
      rec.mirror_version = OfflineMirror::SystemState::current_mirror_version
      rec.local_record_id = 0
      rec.save!
    end
    
    def self.note_record_created_or_updated(model, local_id)
      rec = find_or_initialize_by_model_and_id(model, local_id)
      rec.mirror_version = OfflineMirror::SystemState::current_mirror_version
      rec.save!
    end
    
    def self.find_or_initialize_by_model_and_id(model, local_id)
      model_state_id = OfflineMirror::ModelState::find_or_create_by_model(model).id
      rec = find(:first, :conditions => {
        :model_state_id => model_state_id,
        :local_record_id => local_id
      })
      if rec
        return rec
      else
        return new(
        :model_state_id => model_state_id,
        :local_record_id => local_id,
        :remote_record_id => 0,
        :mirror_version => OfflineMirror::SystemState::current_mirror_version
        )
      end
    end
  end
end
