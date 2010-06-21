module OfflineMirror
  private
  
  class MirrorData
    def initialize(group, data, app_mode = OfflineMirror::app_online? ? "online" : "offline")
      @group = group
      ensure_valid_mode(app_mode)
      @mode = app_mode
      
      # CargoStreamer
      @cs = case data
        when CargoStreamer then data
        when String then CargoStreamer.new(StringIO.new(data), "r")
        when Array then CargoStreamer.new(data[0], data[1])
        else CargoStreamer.new(data, "r")
      end
    end
    
    def write_upwards_data
      # TODO : See if this can be done in some kind of read transaction
      write_data do
        add_group_specific_cargo
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
      read_data do
      end
    end
    
    def load_downwards_data
      read_data do
      end
    end
    
    private
    
    def write_data
      # TODO : See if this can be done in some kind of read transaction
      @cs.write_cargo_section("mirror_info", [MirrorInfo.new_from_group(@group, @mode)], :human_readable => true)
      @cs.write_cargo_section("group_state", [@group.group_state], :human_readable => true)
      yield
    end
    
    def read_data
      OfflineMirror::group_base_model.connection.transaction do
      end
    end
    
    def ensure_valid_mode(mode)
      raise PluginError.new("Invalid app mode") unless ["online", "offline"].include?(mode)
    end
    
    def add_group_specific_cargo
      # FIXME: Ensure that when this is called by the online app, it doesn't put group-specific junk in sendable_records
      # FIXME: Also allow for a full-sync mode (includes all records)
      OfflineMirror::group_owned_models.each do |name, cls|
        add_model_cargo(cls, :conditions => { cls.offline_mirror_group_key.to_sym => @group })
      end
      
      add_model_cargo(OfflineMirror::group_base_model, :conditions => { :id => @group.id })
    end
    
    def add_global_cargo
      # FIXME: Indicate what down-mirror version this is
      # FIXME: Also allow for a full-sync mode (includes all records)
      OfflineMirror::global_data_models.each do |name, cls|
        add_model_cargo(cls)
      end
    end
    
    def add_model_cargo(model, find_options = {})
      # FIXME: Also include id transformation by joining with the mirrored_records table
      # FIXME: Include entries for deleted records
      # FIXME: Check against mirror version
      model.find_in_batches(find_options.merge({:batch_size => 100})) do |batch|
        @cs.write_cargo_section("data_#{model.name}", batch)
      end
    end
  end
end