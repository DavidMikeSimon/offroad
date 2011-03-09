module Offroad
  private
  
  class ReceivedRecordState < ActiveRecord::Base
    set_table_name "offroad_received_record_states"
    
    belongs_to :model_state, :class_name => "::Offroad::ModelState"
    
    belongs_to :group_state, :class_name => "::Offroad::GroupState"
    
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
        if Offroad::app_offline?
          if rec.class.offroad_group_data?
            errors.add_to_base "Cannot create received record state for group data in offline app"
          end
        elsif Offroad::app_online?
          if rec.class.offroad_global_data?
            errors.add_to_base "Cannot create received record state for global records in online app"
          elsif group_state.nil?
            errors.add_to_base "Cannot create received record state for online group records in online app"
          end
        end
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offroad_model_state.id
    } } }
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :group_state_id => (group && group.group_state) ? group.group_state.id : 0
    } } }
    
    named_scope :for_record, lambda { |rec| { :conditions => {
      :model_state_id => rec.class.offroad_model_state.id,
      :group_state_id => rec.class.offroad_group_data? ? rec.group_state.id : 0,
      :local_record_id => rec.id
    } } }
    
    def app_record
      model_state.app_model.find(local_record_id)
    end
    
    def app_record_find_or_initialize
      begin
        return app_record
      rescue ActiveRecord::RecordNotFound
        rec = model_state.app_model.new
        rec.id = local_record_id
        return rec
      end
    end
  end
end
