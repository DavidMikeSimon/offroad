module OfflineMirror
  private
  
  class MirrorData
    attr_reader :group, :mode
    
    def initialize(group, data, app_mode = OfflineMirror::app_online? ? "online" : "offline")
      @group = group
      ensure_valid_mode(app_mode)
      @mode = app_mode
      
      # CargoStreamer
      @cs = case data
        when CargoStreamer then data
        when String then CargoStreamer.new(StringIO.new(data), "r")
        when Array then CargoStreamer.new(data[0], data[1])
        else raise OfflineMirror::PluginError.new("Invalid data format for MirrorData initialization")
      end
    end
    
    def write_upwards_data
      # TODO : See if this can be done in some kind of read transaction
      write_data do
        add_group_specific_cargo(true)
      end
    end
    
    def write_downwards_data
      write_data do
        add_global_cargo
        
        # If this group has no confirmed down mirror, also include all group data to be the offline app's initial state
        if @group.group_state.down_mirror_version == 0
          add_group_specific_cargo
        end
      end
    end
    
    def load_upwards_data
      read_data("offline") do
        import_group_specific_cargo
      end
    end
    
    def load_downwards_data
      read_data("online") do
        import_global_cargo
      end
    end
    
    private
    
    def data_cargo_name_for_model(model)
      "data_#{model.name}"
    end
    
    def deleted_cargo_name_for_model(model)
      "deleted_#{model.name}"
    end
    
    def write_data
      # TODO : See if this can be done in some kind of read transaction
      @cs.write_cargo_section("mirror_info", [MirrorInfo.new_from_group(@group, @mode)], :human_readable => true)
      @cs.write_cargo_section("group_state", [@group.group_state], :human_readable => true)
      yield
    end
    
    def read_data(expected_source_app_mode)
      raise DataError.new("Invalid mirror file, no info section found") unless @cs.has_cargo_named?("mirror_info")
      unless @cs.first_cargo_element("mirror_info").app_mode.downcase == expected_source_app_mode.downcase
        raise DataError.new "Mirror file was generated by app in wrong mode; was expecting #{expected_source_app_mode}"
      end
      
      OfflineMirror::group_base_model.connection.transaction do
        yield
      end
    end
    
    def ensure_valid_mode(mode)
      raise PluginError.new("Invalid app mode") unless ["online", "offline"].include?(mode)
    end
    
    def add_group_specific_cargo(include_deletions = false)
      # FIXME: Test that when this is called by the online app, it doesn't put group-specific junk in sendable_records
      OfflineMirror::group_owned_models.each do |name, cls|
        add_model_cargo(cls, include_deletions, :conditions => { cls.offline_mirror_group_key.to_sym => @group })
      end
      add_model_cargo(OfflineMirror::group_base_model, false, :conditions => { :id => @group.id })
    end
    
    def add_global_cargo(include_deletions = true)
      OfflineMirror::global_data_models.each do |name, cls|
        add_model_cargo(cls, include_deletions)
      end
    end
    
    def add_model_cargo(model, include_deletions, find_options = {})
      # FIXME: Also include id transformation by joining with the mirrored_records table
      # FIXME: Check against mirror version
      model.find_in_batches(find_options.merge({:batch_size => 100})) do |batch|
        @cs.write_cargo_section(data_cargo_name_for_model(model), batch)
      end
      
      if include_deletions
        model_state = ModelState.find_or_create_by_model(model)
        conditions = { :model_state_id => model_state.id, :local_record_id => 0 }
        SendableRecordState.find_in_batches(:batch_size => 100, :conditions => conditions) do |batch|
          @cs.write_cargo_section(deleted_cargo_name_for_model(model), batch)
        end
      end
    end
    
    def import_group_specific_cargo
      OfflineMirror::group_owned_models.each do |name, cls|
        import_model_cargo(cls)
      end
      import_model_cargo(OfflineMirror::group_base_model)
    end
    
    def import_global_cargo
      OfflineMirror::global_data_models.each do |name, cls|
        import_model_cargo(cls)
      end
    end
    
    def import_model_cargo(model, options = {})
      @cs.each_cargo_section(data_cargo_name_for_model(model)) do |batch|
        batch.each do |cargo_record|
          db_record = model.find_or_initialize_by_id(cargo_record.id)
          db_record.bypass_offline_mirror_readonly_checks
          db_record.attributes = cargo_record.attributes
          db_record.save!
        end
      end
      
      @cs.each_cargo_section(deleted_cargo_name_for_model(model)) do |batch|
        id_list = batch.map { |srs| srs.remote_record_id } # Their remote id is our local id
        model.all(:conditions => {:id => id_list}).each do |rec|
          rec.bypass_offline_mirror_readonly_checks
          rec.destroy
        end
      end
    end
  end
end