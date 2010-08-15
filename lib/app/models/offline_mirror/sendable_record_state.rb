module OfflineMirror
  private
  
  class SendableRecordState < ActiveRecord::Base
    set_table_name "offline_mirror_sendable_record_states"
    
    belongs_to :model_state, :class_name => "::OfflineMirror::ModelState"
    
    def validate
      unless model_state
        errors.add_to_base "Cannot find associated model state"
        return
      end
      
      rec = nil
      unless deleted
        begin
          rec = app_record
        rescue ActiveRecord::RecordNotFound
          errors.add_to_base "Cannot find associated app record"
        end
      end
      
      if rec
        if OfflineMirror::app_offline? && app_record.class.offline_mirror_global_data?
          errors.add_to_base "Cannot create sendable record state for global data in offline app"
        elsif OfflineMirror::app_online? && app_record.class.offline_mirror_group_data?
          errors.add_to_base "Cannot create sendable record state for group data in online app"
        end
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offline_mirror_model_state.id
    } } }
    
    named_scope :for_deleted_records, :conditions => { :deleted => true }
    named_scope :for_non_deleted_records, :conditions => { :deleted => false }
    
    named_scope :with_version_greater_than, lambda { |v| { :conditions => ["mirror_version > ?", v] } }
    
    named_scope :for_record, lambda { |rec| { :conditions => {
      :model_state_id => rec.class.offline_mirror_model_state.id,
      :local_record_id => rec.id
    } } }
    
    def app_record
      model_state.app_model.find(local_record_id)
    end
    
    # We put SRS records in mirror files to represent deleted records
    def self.safe_to_load_from_cargo_stream?
      true
    end
    
    def self.note_record_destroyed(record)
      mark_record_changes(record) do |rec|
        rec.deleted = true
      end
    end
    
    def self.note_record_created_or_updated(record)
      mark_record_changes(record)
    end
    
    private
    
    def self.mark_record_changes(record)
      transaction do
        scope = for_record(record)
        rec_state = scope.first || scope.create
        rec_state.lock!
        rec_state.mirror_version = SystemState::current_mirror_version
        yield(rec_state) if block_given?
        rec_state.save!
      end
    end
    
  end
end
