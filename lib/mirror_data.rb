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
        when Array then (
          data[0].is_a?(String) ? CargoStreamer.new(StringIO.new(data[0]), data[1]) : CargoStreamer.new(data[0], data[1])
        )
        else raise OfflineMirror::PluginError.new("Invalid data format for MirrorData initialization")
      end
    end
    
    def write_upwards_data
      write_data do
        add_group_specific_cargo(@group)
      end
    end
    
    def write_downwards_data
      write_data do
        add_global_cargo
      end
    end
    
    def write_initial_downwards_data
      write_data(true) do
        add_global_cargo
        add_group_specific_cargo(@group)
      end
    end
    
    def load_upwards_data
      read_data_from("offline") do |mirror_info|
        import_group_specific_cargo
      end
    end
    
    def load_downwards_data
      read_data_from("online") do |mirror_info|
        group_cargo_name = data_cargo_name_for_model(OfflineMirror::group_base_model)
        if @cs.has_cargo_named?(group_cargo_name) && mirror_info.initial_file
          # This is an initial data file, so we have to delete ALL data currently in the database
          delete_all_existing_database_records!
          
          OfflineMirror::SystemState::create(
            :current_mirror_version => 1,
            :offline_group_id => @cs.first_cargo_element(group_cargo_name).id
          ) or raise PluginError.new("Cannot load initial down mirror file")
          import_global_cargo # Global cargo must be done first because group data might belong_to global data
          import_group_specific_cargo
        elsif SystemState.count == 0
          # If there's no SystemState, then we can't accept non-initial down mirror files
          raise DataError.new("Initial down mirror file required")
        else
          import_global_cargo
        end
      end
    end
    
    private
    
    def data_cargo_name_for_model(model)
      "data_#{model.name}"
    end
    
    def deletion_cargo_name_for_model(model)
      "deletion_#{model.name}"
    end
    
    def delete_all_existing_database_records!
      # Emptying sqlite_sequence resets SQLite's autoincrement counters.
      # SQLite's autoincrement is nice in that automatically picks largest ever id + 1.
      # This means that after clearing sqlite_sequence and then populating database with manually-id'd rows,
      # new records will be inserted with unique id's, no problem.
      tables = ["sqlite_sequence"] + ActiveRecord::Base.connection.tables
      
      tables.each do |table|
        next if table.start_with?("VIRTUAL_")
        next if table == "schema_migrations"
        ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
      end
    end
    
    def write_data(initial_file = false)
      # TODO : See if this can be done in some kind of read transaction
      @cs.write_cargo_section("mirror_info", [MirrorInfo.new_from_group(@group, @mode, initial_file)], :human_readable => true)
      @cs.write_cargo_section("group_state", [@group.group_state], :human_readable => true)
      yield
    end
    
    def read_data_from(expected_source_app_mode)
      raise DataError.new("Invalid mirror file, no info section found") unless @cs.has_cargo_named?("mirror_info")
      mirror_info = @cs.first_cargo_element("mirror_info")
      unless mirror_info.app_mode.downcase == expected_source_app_mode.downcase
        raise DataError.new "Mirror file was generated by app in wrong mode; was expecting #{expected_source_app_mode}"
      end
      
      OfflineMirror::group_base_model.connection.transaction do
        yield mirror_info
      end
    end
    
    def ensure_valid_mode(mode)
      raise PluginError.new("Invalid app mode") unless ["online", "offline"].include?(mode)
    end
    
    def add_group_specific_cargo(group)
      OfflineMirror::group_owned_models.each do |name, cls|
        add_model_cargo(cls, group)
      end
      add_model_cargo(OfflineMirror::group_base_model, group)
    end
    
    def add_global_cargo
      OfflineMirror::global_data_models.each do |name, cls|
        add_model_cargo(cls)
      end
    end
    
    def add_model_cargo(model, group = nil)
      # Include the data for relevant records in this model
      data_source = model
      data_source = data_source.owned_by_offline_mirror_group(group) if group
      data_source.find_in_batches(:batch_size => 100) do |batch|
        @cs.write_cargo_section(data_cargo_name_for_model(model), batch)
      end
      
      # Also need to include information about records that have been destroyed
      deletion_source = SendableRecordState.for_model(model).for_deleted_records
      deletion_source.find_in_batches(:batch_size => 100) do |batch|
        @cs.write_cargo_section(deletion_cargo_name_for_model(model), batch)
      end
    end
    
    def import_group_specific_cargo
      import_model_cargo(OfflineMirror::group_base_model, @group)
      OfflineMirror::group_owned_models.each do |name, cls|
        import_model_cargo(cls, @group)
      end
    end
    
    def import_global_cargo
      OfflineMirror::global_data_models.each do |name, cls|
        import_model_cargo(cls)
      end
    end
    
    def import_model_cargo(model, group = nil)
      rrs_source = OfflineMirror::ReceivedRecordState.for_model(model).for_group(group)
      
      # Update/create records
      @cs.each_cargo_section(data_cargo_name_for_model(model)) do |batch|
        batch.each do |cargo_record|
          # Update the record if we can find it by the RRS, create a new record if we cannot
          rrs = rrs_source.find_by_remote_record_id(cargo_record.id)
          local_record = rrs ? rrs.app_record : model.new
          local_record.bypass_offline_mirror_readonly_checks
          local_record.attributes = cargo_record.attributes
          local_record.save!
          
          # An SRS will have been created for the new record if this record belongs to us
          # If not, it belongs to remote, so create an RSS for this record if it doesn't already have one
          # FIXME This is a terrible way to check if we need to create an RRS
          unless !local_record.offline_mirror_sendable_record_state.new_record? || rrs
            ReceivedRecordState.create_by_record_and_remote_record_id(local_record, cargo_record.id)
          end
        end
      end
      
      # Destroy records here which were destroyed there
      @cs.each_cargo_section(deletion_cargo_name_for_model(model)) do |batch|
        batch.each do |deletion_srs|
          rrs = rrs_source.find_by_remote_record_id(deletion_srs.local_record_id)
          raise DataError.new("Invalid remote id") unless rrs
          local_record = rrs.app_record
          local_record.bypass_offline_mirror_readonly_checks
          local_record.destroy
          rrs.destroy
        end
      end
    end
  end
end
