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
      model = model_state.app_model

      if Offroad::app_offline?
        if model.offroad_group_data?
          errors.add_to_base "Cannot allow received record state for group data in offline app"
        end
      elsif Offroad::app_online?
        if model.offroad_global_data?
          errors.add_to_base "Cannot allow received record state for global records in online app"
        elsif group_state.nil?
          errors.add_to_base "Cannot allow received record state for online group records in online app"
        end
      end

      if model.offroad_global_data? && group_state
        errors.add_to_base "Cannot allow received record state for global records to also be assoc with a group"
      end

      begin
        app_record
      rescue ActiveRecord::RecordNotFound
        errors.add_to_base "Cannot find associated app record"
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :model_state_id => model.offroad_model_state.id
    } } }

    named_scope :for_model_and_group_if_apropos, lambda { |model, group| { :conditions => {
      :model_state_id => model.offroad_model_state.id,
      :group_state_id => (group && model.offroad_group_data? && group.group_state) ? group.group_state.id : 0
    } } }
    
    named_scope :for_record, lambda { |rec| { :conditions => {
      :model_state_id => rec.class.offroad_model_state.id,
      :group_state_id => (rec.class.offroad_group_data? && rec.group_state) ? rec.group_state.id : 0,
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

    def self.redirect_to_local_ids(records, column, model, group)
      column = column.to_sym
      source = self.for_model_and_group_if_apropos(model, group)
      already_allocated = source.all(:conditions => { :remote_record_id => records.map{|r| r[column]} }).index_by(&:remote_record_id)

      remaining = {} # Maps newly discovered remote id to list of records in batch that reference that id
      records.each do |r|
        remote_id = r[column]
        next unless remote_id && remote_id > 0
        # TODO Check for illegal references here (i.e. group model referencing global model)
        if already_allocated.has_key?(remote_id)
          r[column] = already_allocated[remote_id].local_record_id
        else
          # Target doesn't exist yet, we'll figure out what its local id will be later
          if remaining.has_key?(remote_id)
            remaining[remote_id] << r
          else
            remaining[remote_id] = [r]
          end
        end
      end

      return unless remaining.size > 0

      # Reserve access to a block of local ids by creating temporary records to advance the autoincrement counter
      # TODO I'm pretty sure this is safe because it'll always be used in a transaction, but I should check
      model.import([model.primary_key.to_sym], [[nil]]*remaining.size, :validate => false, :timestamps => false)
      last_id = model.last(:select => model.primary_key, :order => model.primary_key).id
      local_ids = (last_id+1-remaining.size)..last_id
      model.delete(local_ids)

      # Create the corresponding RRSes
      model_state_id = model.offroad_model_state.id
      group_state = model.offroad_group_data? && group ? group.group_state : nil
      group_state_id = group_state ? group_state.id : 0
      self.import(
        [:model_state_id, :group_state_id, :local_record_id, :remote_record_id],
        local_ids.zip(remaining.keys).map{|here, there| [model_state_id, group_state_id, here, there]},
        :validate => false, :timestamps => false
      )
      
      # Finally do the redirection to the new ids
      remaining.each_key.each_with_index do |remote_id, i|
        remaining[remote_id].each do |r|
          r[column] = local_ids.first+i
        end
      end
    end
  end
end
