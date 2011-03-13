module Offroad
  private
  
  class SendableRecordState < ActiveRecord::Base
    set_table_name "offroad_sendable_record_states"
    
    belongs_to :model_state, :class_name => "::Offroad::ModelState"
    
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
        if Offroad::app_offline? && app_record.class.offroad_global_data?
          errors.add_to_base "Cannot create sendable record state for global data in offline app"
        elsif Offroad::app_online? && app_record.class.offroad_group_data?
          errors.add_to_base "Cannot create sendable record state for group data in online app"
        end
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offroad_model_state.id
    } } }
    
    named_scope :for_deleted_records, :conditions => { :deleted => true }
    named_scope :for_non_deleted_records, :conditions => { :deleted => false }
    
    named_scope :with_version_greater_than, lambda { |v| { :conditions => ["mirror_version > ?", v] } }
    
    named_scope :for_record, lambda { |rec| { :conditions => {
      :model_state_id => rec.class.offroad_model_state.id,
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

    def self.setup_imported(model, batch)
      model_state_id = model.offroad_model_state.id
      mirror_version = SystemState::current_mirror_version
      self.import(
        [:model_state_id, :local_record_id, :mirror_version],
        batch.map{|r| [model_state_id, r.id, mirror_version]},
        :validate => false,
        :timestamps => false
      )
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
