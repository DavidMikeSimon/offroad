module OfflineMirror
  private
  
  class ReceivedRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_received_record_states"
    
    belongs_to :model_state, :class_name => "::OfflineMirror::ModelState"
    validates_presence_of :model_state
    
    belongs_to :group_state, :class_name => "::OfflineMirror::GroupState"
    validates_presence_of :group_state
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offline_mirror_model_state
    } } }
    
    named_scope :for_group, lambda { |group| { :conditions => {
      :group_state_id => group ? group.group_state : 0
    } } }
    
    def app_record
      model_state.app_model.find(local_record_id)
    end
  end
end
