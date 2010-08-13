module OfflineMirror
  private
  
  class MirrorData
    attr_reader :group, :mode
    
    def initialize(group, options = {})
      @group = group
      @initial_mode = options[:initial_mode] || false
      @skip_write_validation = options[:skip_write_validation] || false
      
      raise PluginError.new("Group required") unless @group || (OfflineMirror::app_offline? && @initial_mode)
      
      @imported_models_to_validate = []
    end
    
    def write_upwards_data(tgt = nil)
      write_data(tgt) do |cs|
        add_group_specific_cargo(cs)
      end
    end
    
    def write_downwards_data(tgt = nil)
      write_data(tgt) do |cs|
        add_global_cargo(cs)
        if @initial_mode
          add_group_specific_cargo(cs)
        end
      end
    end
    
    def load_upwards_data(src)
      raise PluginError.new("Can only load upwards data in online mode") unless OfflineMirror.app_online?
      
      read_data_from("offline", src) do |cs, mirror_info, group_state|
        import_group_specific_cargo(cs)
        
        # Load information into our group state that the offline app is in a better position to know about
        @group.group_state.update_from_remote_group_state!(group_state)
      end
    end
    
    def load_downwards_data(src)
      raise PluginError.new("Can only load downwards data in offline mode") unless OfflineMirror.app_offline?
      
      read_data_from("online", src) do |cs, mirror_info, group_state|
        raise DataError.new("Unexpected initial file value") unless mirror_info.initial_file == @initial_mode
        
        group_cargo_name = MirrorData::data_cargo_name_for_model(OfflineMirror::group_base_model)
        if mirror_info.initial_file
          raise DataError.new("No group data in initial down mirror file") unless cs.has_cargo_named?(group_cargo_name)
          # This is an initial mirror file, so we want it to determine the entirety of the database's new state
          # However, existing data is safe if there's a mid-import error; read_data_from places us in a transaction
          delete_all_existing_database_records!
          
          offline_group_id = cs.first_cargo_element(group_cargo_name).id
          
          OfflineMirror::SystemState::create(
            :offline_group_id => offline_group_id
          ) or raise PluginError.new("Couldn't create valid system state from initial down mirror file")
          import_global_cargo(cs) # Global cargo must be done first because group data might belong_to global data
          import_group_specific_cargo(cs)
        elsif SystemState.count == 0
          # If there's no SystemState, then we can't accept non-initial down mirror files
          raise DataError.new("Initial down mirror file required")
        else
          # Regular, non-initial down mirror file
          import_global_cargo(cs)
        end
        
        # If we've just set up a new offline group, do some initialization work on the group state
        if @initial_mode
          @group = OfflineMirror::offline_group
          @group.group_state.setup_as_new_offline_group!
        end
        
        # Load information into our group state that the online app is in a better position to know about
        @group.group_state.update_from_remote_group_state!(group_state)
      end
    end
    
    private
    
    def self.data_cargo_name_for_model(model)
      "data_#{model.name}"
    end
    
    def self.deletion_cargo_name_for_model(model)
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
    
    def write_data(tgt)
      cs = nil
      temp_sio = nil
      case tgt
        when CargoStreamer
          cs = tgt
        when nil
          temp_sio = StringIO.new("", "w")
          cs = CargoStreamer.new(temp_sio, "w")
        else
          cs = CargoStreamer.new(tgt, "w")
      end
      
      # TODO : See if this whole thing can be done in some kind of read transaction
      
      mirror_info = MirrorInfo.new_from_group(@group, OfflineMirror::app_online? ? "online" : "offline", @initial_mode)
      cs.write_cargo_section("mirror_info", [mirror_info], :human_readable => true)
      
      group_state = @group.group_state
      if OfflineMirror::app_online?
        # Let the offline app know what global data version it's being updated to
        group_state.global_data_version = SystemState::global_data_version
      end
      cs.write_cargo_section("group_state", [group_state], :human_readable => true)
      
      yield cs
      
      return temp_sio.string if temp_sio
    end
    
    def read_data_from(expected_source_app_mode, src)
      cs = case src
        when CargoStreamer then src
        when String then CargoStreamer.new(StringIO.new(src, "r"), "r")
        else CargoStreamer.new(src, "r")
      end
      
      raise DataError.new("Invalid mirror file, no info section found") unless cs.has_cargo_named?("mirror_info")
      mirror_info = cs.first_cargo_element("mirror_info")
      unless mirror_info.app_mode.downcase == expected_source_app_mode.downcase
        raise DataError.new "Mirror file was generated by app in wrong mode; was expecting #{expected_source_app_mode}"
      end
      group_state = cs.first_cargo_element("group_state")
      
      OfflineMirror::group_base_model.connection.transaction do
        yield cs, mirror_info, group_state
        validate_imported_models(cs)
      end
    end
    
    def add_group_specific_cargo(cs)
      OfflineMirror::group_owned_models.each do |name, model|
        add_model_cargo(cs, model)
      end
      add_model_cargo(cs, OfflineMirror::group_base_model)
    end
    
    def add_global_cargo(cs)
      OfflineMirror::global_data_models.each do |name, model|
        add_model_cargo(cs, model)
      end
    end
    
    def add_model_cargo(cs, model)
      # Include the data for relevant records in this model
      data_source = model
      data_source = data_source.owned_by_offline_mirror_group(@group) if model.offline_mirror_group_data? && @group
      data_source.find_in_batches(:batch_size => 100) do |batch|
        cs.write_cargo_section(MirrorData::data_cargo_name_for_model(model), batch, :skip_validation => @skip_write_validation)
        
        if @initial_mode && model.offline_mirror_group_data?
          # In initial mode the remote app will create records with the same id's as the corresponding records here
          # So we'll create RRSes indicating that we 'received' the data we're about to send
          # Later when the remote app sends new information on those records, we'll know which ones it means
          rrs_source = OfflineMirror::ReceivedRecordState.for_model(model).for_group(@group)
          batch.each do |rec|
            existing_rrs = rrs_source.find_by_remote_record_id(rec.id)
            ReceivedRecordState.for_record(rec).create!(:remote_record_id => rec.id) unless existing_rrs
          end
        end
      end
      
      unless @initial_mode
        # Also need to include information about records that have been destroyed
        deletion_source = SendableRecordState.for_model(model).for_deleted_records
        deletion_source.find_in_batches(:batch_size => 100) do |batch|
          cs.write_cargo_section(MirrorData::deletion_cargo_name_for_model(model), batch)
        end
      end
    end
    
    def import_group_specific_cargo(cs)
      import_model_cargo(cs, OfflineMirror::group_base_model)
      OfflineMirror::group_owned_models.each do |name, model|
        import_model_cargo(cs, model)
      end
    end
    
    def import_global_cargo(cs)
      OfflineMirror::global_data_models.each do |name, model|
        import_model_cargo(cs, model)
      end
    end
    
    def import_model_cargo(cs, model)
      @imported_models_to_validate.push model
      
      rrs_source = ReceivedRecordState.for_model(model)
      rrs_source = rrs_source.for_group(@group) if model.offline_mirror_group_data?
      
      # Update/create records
      cs.each_cargo_section(MirrorData::data_cargo_name_for_model(model)) do |batch|
        batch.each do |cargo_record|
          # Update the record if we're not in initial mode and can find it by the RRS, create a new record otherwise
          rrs, local_record = nil, nil
          if @initial_mode
            local_record = model.new
            # Conveniently, SQLite's autoincrement columns keep track of manually set values.
            # So, below is safe on the offline app; newly created group records will have next biggest ID.
            local_record.id = cargo_record.id
          else
            rrs = rrs_source.find_by_remote_record_id(cargo_record.id)
            local_record = rrs ? rrs.app_record : model.new
          end
          
          local_record.send(:attributes=, cargo_record.attributes.reject{|k,v| k == "id"}, false)
          
          # Update foreign key associations so they point to the same actual records as they did on the remote system
          unless @initial_mode
            model.offline_mirror_foreign_key_models.each_pair do |column_name, foreign_model|
              remote_foreign_id = local_record.send(column_name.to_sym)
              if remote_foreign_id && remote_foreign_id != 0
                foreign_rrs_source = ReceivedRecordState.for_model(foreign_model)
                foreign_rrs_source = foreign_rrs_source.for_group(@group) if foreign_model.offline_mirror_group_data?
                foreign_rrs = foreign_rrs_source.find_by_remote_record_id(remote_foreign_id)
                if !foreign_rrs
                  # If the foreign record doesn't already exist, then it hasn't yet been imported.
                  # Just create an empty one for now to be filled in later, so we have a known local id to point at.
                  # Later when it's imported, we will update the same record based on this RRS.
                  # FIXME: If we never end up importing the record, the placeholder should be deleted.
                  # However, need to leave the RRS in case it is imported in another mirror file later.
                  # Alternate idea: simply create then immediately destroy record, just to get an autoincremented id
                  foreign_rec_placeholder = foreign_model.new
                  foreign_rec_placeholder.bypass_offline_mirror_readonly_checks
                  foreign_rec_placeholder.save_without_validation
                  foreign_rrs = foreign_rrs_source.create!(
                    :local_record_id => foreign_rec_placeholder.id,
                    :remote_record_id => remote_foreign_id
                  )
                end
                local_record.send("#{column_name}=".to_sym, foreign_rrs.local_record_id)
              end
            end
          end
          
          local_record.bypass_offline_mirror_readonly_checks
          local_record.save_without_validation # Validation delayed because it might depend on as-yet unimported data
          
          unless (@initial_mode && model.offline_mirror_group_data?) || rrs
            ReceivedRecordState.for_record(local_record).create!(:remote_record_id => cargo_record.id)
          end
        end
      end
      
      # Destroy records here which were destroyed there
      unless @initial_mode
        cs.each_cargo_section(MirrorData::deletion_cargo_name_for_model(model)) do |batch|
          batch.each do |deletion_srs|
            rrs = rrs_source.find_by_remote_record_id(deletion_srs.local_record_id)
            raise DataError.new("Invalid id for deletion: #{model.name} #{deletion_srs.local_record_id}") unless rrs
            local_record = rrs.app_record
            local_record.bypass_offline_mirror_readonly_checks
            local_record.destroy
            rrs.destroy
          end
        end
      end
    end
    
    def validate_imported_models(cs)
      while @imported_models_to_validate.size > 0
        model = @imported_models_to_validate.pop
        
        rrs_source = nil
        unless @initial_mode
          rrs_source = OfflineMirror::ReceivedRecordState.for_model(model)
          rrs_source = rrs_source.for_group(@group) if model.offline_mirror_group_data?
        end
        
        cs.each_cargo_section(MirrorData::data_cargo_name_for_model(model)) do |batch|
          batch.each do |cargo_record|
            rec = nil
            if @initial_mode
              rec = model.find_by_id(cargo_record.id) # Not using find because that raises exception on not-found
            else
              rec = rrs_source.find_by_remote_record_id(cargo_record.id).app_record
            end
            
            unless rec && rec.valid?
              raise OfflineMirror::DataError.new("Invalid record found in mirror data")
            end
          end
        end
      end
    end
  end
end
