module OfflineMirror
  module ModelExtensions
    OFFLINE_MIRROR_VALID_MODES = [:group_base, :group_owned, :global]
    OFFLINE_MIRROR_GROUP_MODES = [:group_base, :group_owned]
    
    def acts_as_mirrored_offline(mode, opts = {})
      raise ModelError.new("You can only call acts_as_mirrored_offline once per model") if acts_as_mirrored_offline?
      raise ModelError.new("You must specify a mode, one of " + OFFLINE_MIRROR_VALID_MODES.map(&:inspect).join("/")) unless OFFLINE_MIRROR_VALID_MODES.include?(mode)
      
      set_internal_cattr :offline_mirror_mode, mode
      
      case mode
      when :group_owned then
        raise ModelError.new("For :group_owned models, need to specify :group_key, an attribute name for this model's owning group") unless opts[:group_key]
        begin
          raise ModelError.new("The :group_key is invalid, there's no column with that name") unless columns.include?(opts[:group_key].to_s)
        rescue
          unless opts[:group_key].to_s.end_with?("_id")
            opts[:group_key] = opts[:group_key].to_s + "_id"
            retry
          end
        end
        set_internal_cattr :offline_mirror_group_key, opts.delete(:group_key).to_sym
        OfflineMirror::note_group_owned_model(self)
      when :group_base then
        OfflineMirror::note_group_base_model(self)
      when :global then
        OfflineMirror::note_global_data_model(self)
      end
      
      # We should have deleted all the options from the hash by this point
      raise ModelError.new("Unknown or inapplicable option(s) specified") unless opts.size == 0
      
      if offline_mirror_group_data?
        include GroupDataInstanceMethods
      else
        include GlobalDataInstanceMethods
      end
      include CommonInstanceMethods
      before_destroy :before_mirrored_data_destroy
      after_destroy :after_mirrored_data_destroy
      before_save :before_mirrored_data_save
      after_save :after_mirrored_data_save
    end
    
    def acts_as_mirrored_offline?
      respond_to? :offline_mirror_mode
    end
    
    def offline_mirror_group_data?
      raise ModelError.new("You must call acts_as_offline_mirror for this model") unless acts_as_mirrored_offline?
      OFFLINE_MIRROR_GROUP_MODES.include?(offline_mirror_mode)
    end
    
    def offline_mirror_global_data?
      raise ModelError.new("You must call acts_as_offline_mirror for this model") unless acts_as_mirrored_offline?
      offline_mirror_mode == :global
    end
    
    private
    
    def set_internal_cattr(name, value)
      write_inheritable_attribute name, value
      class_inheritable_reader name
    end
    
    module CommonInstanceMethods
      # This method allows a record to be saved or destroyed *once*, even when
      # this would otherwise not be allowed due to i.e. trying to edit an
      # offline group's data in the online app, trying to edit a global record
      # in the offline app, etc. Do not use this method unless it's really
      # necessary.
      def bypass_offline_mirror_readonly_checks
        @offline_mirror_readonly_bypassed = true
      end
      
      private
      
      def checks_bypassed?
        if @offline_mirror_readonly_bypassed
          @offline_mirror_readonly_bypassed = false
          return true
        end
        return false
      end
      
      def validate_changed_id_columns
        changed.each do |colname|
          raise DataError.new("Cannot change id of offline-mirror tracked records") if colname == "id"
          
          if !new_record? and offline_mirror_mode == :group_owned and colname == offline_mirror_group_key.to_s
            raise DataError.new("Ownership of group-owned data cannot be transferred between groups")
          end
          
          next unless colname.end_with? "_id"
          accessor_name = colname[0, colname.size-3]
          next unless respond_to? accessor_name
          obj = send(accessor_name)
          
          raise DataError.new("Mirrored data cannot hold a foreign key to unmirrored data") unless obj.class.acts_as_mirrored_offline?
          
          if self.class.offline_mirror_group_data?
            if obj.class.offline_mirror_group_data? && obj.owning_group.id != owning_group.id
              raise DataError.new("Invalid #{colname}: Group data cannot hold a foreign key to data owned by another group")
            end
          elsif self.class.offline_mirror_global_data?
            unless obj.class.offline_mirror_global_data?
              raise DataError.new("Invalid #{colname}: Global mirrored data cannot hold a foreign key to group data")
            end
          end
        end
      end
      
    end
    
    module GlobalDataInstanceMethods
      # Methods below this point are only to be used internally by OfflineMirror
      # However, marking all of them private would make using them from elsewhere in the plugin troublesome
      
      #:nodoc#
      def before_mirrored_data_destroy
        return true if checks_bypassed?
        ensure_online
        return true
      end
      
      #:nodoc#
      def after_mirrored_data_destroy
        OfflineMirror::SendableRecord::note_record_destroyed(self.class, id)
        return true
      end
      
      #:nodoc#
      def before_mirrored_data_save
        return true if checks_bypassed?
        ensure_online
        validate_changed_id_columns
        return true
      end
      
      #:nodoc#
      def after_mirrored_data_save
        OfflineMirror::SendableRecord::note_record_created_or_updated(self.class, id)
        return true
      end
      
      private
      
      def ensure_online
        # Only the online app can change global data
        raise ActiveRecord::ReadOnlyRecord if OfflineMirror::app_offline?
      end
    end
    
    module GroupDataInstanceMethods
      def locked_by_offline_mirror?
        OfflineMirror::app_online? && group_offline?
      end
      
      # If called on a group_owned_model, methods below bubble up to the group_base_model
      
      # Returns a hash with the latest information about this group in the offline app
      def last_known_status
        raise DataError.new("This method is only for offline groups") if group_online?
        s = group_state
        fields_of_interest = [
          :last_installer_downloaded_at,
          :last_installation_at,
          :last_down_mirror_created_at,
          :last_down_mirror_loaded_at,
          :last_up_mirror_created_at,
          :last_up_mirror_loaded_at,
          :launcher_version,
          :app_version,
          :last_known_offline_os
        ]
        return fields_of_interest.map {|field_name| s.send(field_name)}
      end
      
      def group_offline?
        not group_online?
      end
      
      def group_online?
        # We cannot get group_state if the record isn't saved...
        # But, we know that the default state of newly created groups is online
        new_record? or group_state.online?
      end
      
      def group_offline=(b)
        raise DataError.new("Unable to change a group's offline status in offline app") if OfflineMirror::app_offline?
        group_state.update_attribute(:offline, b)
      end
      
      def owning_group
        case offline_mirror_mode
          when :group_owned then return OfflineMirror::group_base_model.find_by_id(owning_group_id)
          when :group_base then return self
        end
      end
      
      def owning_group_id
        case offline_mirror_mode
          when :group_owned then return self.send offline_mirror_group_key
          when :group_base then return new_record? ? nil : self.id
        end
      end
      
      # Methods below this point are only to be used internally by OfflineMirror
      # However, marking them private makes using them from elsewhere in the plugin troublesome
      
      #:nodoc#
      def before_mirrored_data_destroy
        if offline_mirror_mode == :group_base
          group_state.update_attribute(:group_being_destroyed, true)
        end
        
        return true if checks_bypassed?
        
        if group_offline?
          # If the app is online, the only thing that can be deleted is the entire group (possibly with its records)
          # If the app is offline, the only thing that CAN'T be deleted is the group
          raise ActiveRecord::ReadOnlyRecord if OfflineMirror::app_offline? and offline_mirror_mode == :group_base
          raise ActiveRecord::ReadOnlyRecord if OfflineMirror::app_online? and offline_mirror_mode != :group_base and !group_being_destroyed
        end
        
        return true
      end
      
      #:nodoc#
      def after_mirrored_data_destroy
        OfflineMirror::SendableRecord::note_record_destroyed(self.class, id)
        return true
      end
      
      #:nodoc#
      def before_mirrored_data_save
        return true if checks_bypassed?
        
        raise DataError.new("Invalid owning group") if owning_group == nil
        raise ActiveRecord::ReadOnlyRecord if locked_by_offline_mirror?
        
        if OfflineMirror::app_offline?
          case offline_mirror_mode
          when :group_base
            raise DataError.new("Cannot create groups in offline mode") if new_record?
          when :group_owned
            raise DataError.new("Owning group must be the offline group") if owning_group_id != OfflineMirror::SystemState::offline_group_id
          end
        end
        
        validate_changed_id_columns
        return true
      end
      
      #:nodoc#
      def after_mirrored_data_save
        OfflineMirror::SendableRecord::note_record_created_or_updated(self.class, id)
        return true
      end
      
      #:nodoc#
      def group_state
        OfflineMirror::GroupState.find_or_create_by_group(owning_group)
      end
      
      private
      
      def group_being_destroyed
        return true unless owning_group # If the group doesn't exist anymore, then it's pretty well "destroyed"
        return group_state.group_being_destroyed
      end
    end
  end
end
