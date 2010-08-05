module OfflineMirror
  private
  
  class ReceivedRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_received_record_states"
    
    belongs_to :model_state, :class_name => "::OfflineMirror::ModelState"
    validates_presence_of :model_state
    
    belongs_to :group_state, :class_name => "::OfflineMirror::GroupState"
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offline_mirror_model_state
    } } }
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :group_state_id => group ? group.group_state : 0
    } } }
    
    def app_record
      model_state.app_model.find(local_record_id)
    end
    
    def self.create_by_record_and_remote_record_id(rec, remote_record_id)
      if rec.new_record?
        raise DataError.new("Cannot build record state for unsaved record")
      end
      
      unless rec.class.acts_as_mirrored_offline?
        raise ModelError.new("Cannot build record state for unmirrored record")
      end
      
      create(
        :model_state_id => rec.class.offline_mirror_model_state.id,
        :group_state_id => rec.class.offline_mirror_group_data? ? rec.group_state.id : 0,
        :local_record_id => rec.id,
        :remote_record_id => remote_record_id
      )
    end
  end
end
