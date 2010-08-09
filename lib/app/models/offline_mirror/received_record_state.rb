module OfflineMirror
  private
  
  class ReceivedRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_received_record_states"
    
    belongs_to :model_state, :class_name => "::OfflineMirror::ModelState"
    
    belongs_to :group_state, :class_name => "::OfflineMirror::GroupState"
    
    def validate
      unless model_state
        errors.add_to_base "Cannot find associated model state"
        return
      end
      
      rec = nil
      begin
        rec = app_record
      rescue ActiveRecord::RecordNotFound
        errors.add_to_base "Cannot find associated app record"
      end
      
      if rec
        if OfflineMirror::app_offline?
          if rec.class.offline_mirror_group_data?
            errors.add_to_base "Cannot create received record state for group data in offline app"
          end
        elsif OfflineMirror::app_online?
          if rec.class.offline_mirror_global_data?
            errors.add_to_base "Cannot create received record state for global records in online app"
          elsif group_state.nil?
            errors.add_to_base "Cannot create received record state for online group records in online app"
          end
        end
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offline_mirror_model_state.id
    } } }
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :group_state_id => (group && group.group_state) ? group.group_state.id : 0
    } } }
    
    named_scope :for_record, lambda { |rec| { :conditions => {
      :model_state_id => rec.class.offline_mirror_model_state.id,
      :group_state_id => rec.class.offline_mirror_group_data? ? rec.group_state.id : 0,
      :local_record_id => rec.id
    } } }
    
    def app_record
      model_state.app_model.find(local_record_id)
    end
  end
end
