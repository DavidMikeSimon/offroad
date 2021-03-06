module Offroad
  private
  
  class MirrorData
    attr_reader :group, :mode
    
    def initialize(group, options = {})
      @group = group
      @initial_mode = options.delete(:initial_mode) || false
      @skip_validation = options.delete(:skip_validation) || false
      
      raise PluginError.new("Invalid option keys") unless options.size == 0
      
      unless Offroad::app_offline? && @initial_mode
        raise PluginError.new("Need group") unless @group.is_a?(Offroad::group_base_model) && !@group.new_record?
        raise DataError.new("Group must be in offline mode") unless @group.group_offline?
      end

      @imported_models_to_validate = []
    end
    
    def write_upwards_data(tgt = nil)
      raise PluginError.new("Can only write upwards data in offline mode") unless Offroad.app_offline?
      raise PluginError.new("No such thing as initial upwards data") if @initial_mode
      write_data(tgt) do |cs|
        add_group_specific_cargo(cs)
      end
    end
    
    def write_downwards_data(tgt = nil)
      raise PluginError.new("Can only write downwards data in online mode") unless Offroad.app_online?
      write_data(tgt) do |cs|
        add_global_cargo(cs)
        if @initial_mode
          add_group_specific_cargo(cs)
        end
      end
    end
    
    def load_upwards_data(src)
      raise PluginError.new("Can only load upwards data in online mode") unless Offroad.app_online?
      raise PluginError.new("No such thing as initial upwards data") if @initial_mode

      read_data_from("offline", src) do |cs, mirror_info, cargo_group_state|
        unless cargo_group_state.confirmed_group_data_version > @group.group_state.confirmed_group_data_version
          raise OldDataError.new("File contains old up-mirror data")
        end
        import_group_specific_cargo(cs)
        @group.group_offline = false if cargo_group_state.group_locked?
      end
    end
    
    def load_downwards_data(src)
      raise PluginError.new("Can only load downwards data in offline mode") unless Offroad.app_offline?
      
      read_data_from("online", src) do |cs, mirror_info, cargo_group_state|
        raise DataError.new("Unexpected initial file value") unless mirror_info.initial_file == @initial_mode
        
        group_cargo_name = MirrorData::data_cargo_name_for_model(Offroad::group_base_model)
        if mirror_info.initial_file
          raise DataError.new("No group data in initial down mirror file") unless cs.has_cargo_named?(group_cargo_name)
          # This is an initial mirror file, so we want it to determine the entirety of the database's new state
          # However, existing data is safe if there's a mid-import error; read_data_from places us in a transaction
          delete_all_existing_database_records!
          
          import_global_cargo(cs) # Global cargo must be done first because group data might belong_to global data
          import_group_specific_cargo(cs)
        else
          # Regular, non-initial down mirror file
          unless cargo_group_state.confirmed_global_data_version > @group.group_state.confirmed_global_data_version
            raise OldDataError.new("File contains old down-mirror data")
          end
          import_global_cargo(cs)
        end
        
        # Load information into our group state that the online app is in a better position to know about
        @group = Offroad::offline_group if @initial_mode
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
      tables = ActiveRecord::Base.connection.tables
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("sqlite")
        # Emptying sqlite_sequence resets SQLite's autoincrement counters.
        # SQLite's autoincrement is nice in that it automatically picks largest ever id + 1.
        # This means that after clearing sqlite_sequence and then populating database with manually-id'd rows,
        # new records will be inserted with unique id's, no problem.
        tables << "sqlite_sequence"
      end
      
      tables.each do |table|
        next if table.start_with?("virtual_") # Used in testing # FIXME Should pick something less likely to collide with app name
        next if table == "schema_migrations"
        ActiveRecord::Base.connection.execute "DELETE FROM #{table}"
      end
        
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
        # Reset all sequences so that autoincremented ids start from 1 again
        seqnames = ActiveRecord::Base.connection.select_values "SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'"
        seqnames.each do |s|
          ActiveRecord::Base.connection.execute "SELECT setval('#{s}', 1, false)"
        end
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

      # TODO: Figure out if this transaction ensures we get a consistent read state
      Offroad::group_base_model.connection.transaction do
        Offroad::group_base_model.cache do
          begin
            mirror_info = MirrorInfo.new_from_group(@group, @initial_mode)
            cs.write_cargo_section("mirror_info", [mirror_info], :human_readable => true)
            
            group_state = @group.group_state
            if Offroad::app_online?
              # Let the offline app know what global data version it's being updated to
              group_state.confirmed_global_data_version = SystemState::current_mirror_version
            else
              # Let the online app know what group data version the online mirror of this group is being updated to
              group_state.confirmed_group_data_version = SystemState::current_mirror_version
            end
            cs.write_cargo_section("group_state", [group_state], :human_readable => true)
            
            yield cs
            
            SystemState::increment_mirror_version
          rescue Offroad::CargoStreamerError
            raise Offroad::DataError.new("Encountered data validation error while writing to cargo file")
          end
        end
      end
      
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
      raise DataError.new("Invalid info section type") unless mirror_info.is_a?(MirrorInfo)
      unless mirror_info.app_mode.downcase == expected_source_app_mode.downcase
        raise DataError.new "Mirror file was generated by app in wrong mode; was expecting #{expected_source_app_mode}"
      end
      
      raise DataError.new("Invalid mirror file, no group state found") unless cs.has_cargo_named?("group_state")
      group_state = cs.first_cargo_element("group_state")
      raise DataError.new("Invalid group state type") unless group_state.is_a?(GroupState)
      group_state.readonly!
      
      # FIXME: Is this transaction call helping at all?
      Offroad::group_base_model.connection.transaction do
        Offroad::group_base_model.cache do
          yield cs, mirror_info, group_state
          validate_imported_models(cs) unless @skip_validation
                  
          # Load information into our group state that the remote app is in a better position to know about
          @group.group_state.update_from_remote_group_state!(group_state) if @group && @group.group_offline?
        end
      end
      
      SystemState::increment_mirror_version if @initial_mode
    end
    
    def add_group_specific_cargo(cs)
      Offroad::group_owned_models.each do |name, model|
        add_model_cargo(cs, model)
      end
      Offroad::group_single_models.each do |name, model|
        add_model_cargo(cs, model)
      end
      add_model_cargo(cs, Offroad::group_base_model)
    end
    
    def add_global_cargo(cs)
      Offroad::global_data_models.each do |name, model|
        add_model_cargo(cs, model)
      end
    end
    
    def add_model_cargo(cs, model)
      if @initial_mode
        add_initial_model_cargo(cs, model)
      else
        add_non_initial_model_cargo(cs, model)
      end
    end
    
    def add_initial_model_cargo(cs, model)
      # Include the data for relevant records in this model
      data_source = model
      data_source = data_source.owned_by_offroad_group(@group) if model.offroad_group_data? && @group
      data_source.find_in_batches(:batch_size => 100) do |batch|
        cs.write_cargo_section(
          MirrorData::data_cargo_name_for_model(model),
          batch,
          :skip_validation => @skip_validation
        )
        
        if model.offroad_group_data?
          # In initial mode the remote app will create records with the same id's as the corresponding records here
          # So we'll create RRSes indicating that we've already "received" the data we're about to send
          # Later when the remote app sends new information on those records, we'll know which ones it means
          rrs_source = Offroad::ReceivedRecordState.for_model_and_group_if_apropos(model, @group)
          existing_rrs = rrs_source.all(:conditions => {:remote_record_id => batch.map(&:id)}).index_by(&:remote_record_id)
          new_rrs = batch.reject{|r| existing_rrs.has_key?(r.id)}.map{|r| rrs_source.for_record(r).new(:remote_record_id => r.id)}
          if new_rrs.size > 0
            Offroad::ReceivedRecordState.import(new_rrs, :validate => false, :timestamps => false)
          end
        end
      end
    end
    
    def add_non_initial_model_cargo(cs, model)
      # Include the data for relevant records in this model that are newer than the remote side's known latest version
      gs = @group.group_state
      remote_version = nil
      if model.offroad_group_data?
        remote_version = gs.confirmed_group_data_version
      else
        remote_version = gs.confirmed_global_data_version
      end
      srs_source = SendableRecordState.for_model(model).with_version_greater_than(remote_version)
      srs_source.for_non_deleted_records.find_in_batches(:batch_size => 100) do |srs_batch|
        # TODO Might be able to optimize this to one query using a join on app model and SRS tables
        record_ids = srs_batch.map { |srs| srs.local_record_id }
        data_batch = model.find(:all, :conditions => {:id => record_ids})
        raise PluginError.new("Invalid SRS ids") if data_batch.size != srs_batch.size
        cs.write_cargo_section(
          MirrorData::data_cargo_name_for_model(model),
          data_batch,
          :skip_validation => @skip_validation
        )
      end
      
      # Also need to include information about records that have been destroyed
      srs_source.for_deleted_records.find_in_batches(:batch_size => 100) do |deletion_batch|
        cs.write_cargo_section(MirrorData::deletion_cargo_name_for_model(model), deletion_batch)
      end
    end
    
    def import_group_specific_cargo(cs)
      import_model_cargo(cs, Offroad::group_base_model)
      Offroad::group_owned_models.each do |name, model|
        import_model_cargo(cs, model)
      end
      Offroad::group_single_models.each do |name, model|
        import_model_cargo(cs, model)
      end
    end
    
    def import_global_cargo(cs)
      Offroad::global_data_models.each do |name, model|
        import_model_cargo(cs, model)
      end
    end
    
    def import_model_cargo(cs, model)
      @imported_models_to_validate.push model
      
      if @initial_mode && model.offroad_group_data?
        import_initial_model_cargo(cs, model)
      else
        import_non_initial_model_cargo(cs, model)
      end
    end

    def import_initial_model_cargo(cs, model)
      cs.each_cargo_section(MirrorData::data_cargo_name_for_model(model)) do |batch|
        # Notice we are using the same primary key values as the online system, not allocating new ones
        model.import batch, :validate => false, :timestamps => false
        if model.offroad_group_base? && batch.size > 0
          GroupState.for_group(model.first).create!
        end
        SendableRecordState.setup_imported(model, batch)
        if model.instance_methods.include?("after_offroad_upload")
          batch.each { |rec| rec.after_offroad_upload }
        end
      end
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
        # Need to adjust the sequences so that records inserted from this point on don't collide with existing ids
        cols = ActiveRecord::Base.connection.select_rows "select table_name, column_name, column_default from information_schema.columns WHERE column_default like 'nextval%'"
        cols.each do |table_name, column_name, column_default|
          if column_default =~ /nextval\('(.+)'(?:::.+)?\)/
            seqname = $1
            ActiveRecord::Base.connection.execute "SELECT setval('#{seqname}', (SELECT MAX(\"#{column_name}\") FROM \"#{table_name}\"))"
          end
        end
      end
    end

    def import_non_initial_model_cargo(cs, model)
      rrs_source = ReceivedRecordState.for_model_and_group_if_apropos(model, @group)

      # Update/create records
      cs.each_cargo_section(MirrorData::data_cargo_name_for_model(model)) do |batch|
        # Update foreign key associations to use local ids instead of remote ids
        model.reflect_on_all_associations(:belongs_to).each do |a|
          ReceivedRecordState.redirect_to_local_ids(batch, a.primary_key_name, a.klass, @group)
        end

        # Delete existing records in the database; that way we can just do INSERTs, don't have to worry about UPDATEs
        # TODO: Is this necessary? Perhaps ar-extensions can deal with a mix of new and updated records...
        model.delete rrs_source.all(:conditions => {:remote_record_id => batch.map(&:id)} ).map(&:local_record_id)

        # Update the primary keys to use local ids, then insert the records
        ReceivedRecordState.redirect_to_local_ids(batch, model.primary_key, model, @group)
        model.import batch, :validate => false, :timestamps => false

        if model.instance_methods.include?("after_offroad_upload")
          batch.each { |rec| rec.after_offroad_upload }
        end
      end

      # Delete records here which were destroyed there (except for group_base records, that would cause trouble)
      return if model == Offroad::group_base_model
      cs.each_cargo_section(MirrorData::deletion_cargo_name_for_model(model)) do |batch|
        # If there's a callback, we need to load the local records before deleting them
        local_recs = []
        if model.instance_methods.include?("after_offroad_destroy")
          local_recs = model.all(:conditions => {:id => batch.map(&:local_record_id)})
        end

        # Each deletion batch is made up of SendableRecordStates from the remote system
        dying_rrs_batch = rrs_source.all(:conditions => {:remote_record_id => batch.map(&:local_record_id)})
        model.delete dying_rrs_batch.map(&:local_record_id)
        ReceivedRecordState.delete dying_rrs_batch.map(&:id)
        local_recs.each { |rec| rec.after_offroad_destroy }
      end
    end

    def validate_imported_models(cs)
      Offroad::group_base_model.connection.clear_query_cache
      while @imported_models_to_validate.size > 0
        model = @imported_models_to_validate.pop
        rrs_source = Offroad::ReceivedRecordState.for_model_and_group_if_apropos(model, @group)
        
        cs.each_cargo_section(MirrorData::data_cargo_name_for_model(model)) do |cargo_batch|
          if @initial_mode
            local_batch = model.all(:conditions => {:id => cargo_batch.map(&:id)})
          else
            local_rrs_batch = rrs_source.all(:conditions => {:remote_record_id => cargo_batch.map(&:id)})
            local_batch = model.all(:conditions => {:id => local_rrs_batch.map(&:local_record_id)})
          end
          raise Offroad::DataError.new("Invalid record found in mirror data") unless local_batch.all?(&:valid?)
        end
      end
    end
  end
end
