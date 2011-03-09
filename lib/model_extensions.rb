module Offroad
  module ModelExtensions
    OFFROAD_VALID_MODES = [:group_base, :group_owned, :global, :naive_sync]
    OFFROAD_GROUP_MODES = [:group_base, :group_owned]

    def acts_as_offroadable(mode, opts = {})
      raise ModelError.new("You can only call acts_as_offroadable once per model") if acts_as_offroadable?
      raise ModelError.new("You must specify a mode, one of " + OFFROAD_VALID_MODES.map(&:inspect).join("/")) unless OFFROAD_VALID_MODES.include?(mode)

      set_internal_cattr :offroad_mode, mode

      case mode
      when :group_owned then
        raise ModelError.new("For :group_owned models, need to specify :parent") unless opts[:parent]
        assoc = reflect_on_association(opts.delete(:parent))
        raise ModelError.new("No such parent associaton") unless assoc
        raise ModelError.new("Parent association must be a belongs_to association") unless assoc.belongs_to?
        raise ModelError.new("Parent association must be to a group data model") unless assoc.klass.offroad_group_data?

        set_internal_cattr :offroad_parent_assoc, assoc
        Offroad::note_group_owned_model(self)
      when :group_base then
        Offroad::note_group_base_model(self)
      when :global then
        Offroad::note_global_data_model(self)
      when :naive_sync then
        Offroad::note_naive_sync_model(self)
      end

      # We should have deleted all the options from the hash by this point
      raise ModelError.new("Unknown or inapplicable option(s) specified") unless opts.size == 0

      case mode
      when :group_base then
        named_scope :owned_by_offroad_group, lambda { |group| { :conditions => { :id => group.id } } }
        named_scope :offline_groups, {
          :joins =>
          "INNER JOIN `#{Offroad::GroupState.table_name}` ON `#{Offroad::GroupState.table_name}`.app_group_id = `#{table_name}`.`#{primary_key}`"
        }
        named_scope :online_groups, {
          :joins =>
          "LEFT JOIN `#{Offroad::GroupState.table_name}` ON `#{Offroad::GroupState.table_name}`.app_group_id = `#{table_name}`.`#{primary_key}`",
          :conditions =>
          "`#{Offroad::GroupState.table_name}`.app_group_id IS NULL"
        }
      when :group_owned then
        named_scope :owned_by_offroad_group, lambda { |group| args_for_ownership_scope(group) }
      end

      if offroad_group_data?
        include GroupDataInstanceMethods
      elsif offroad_global_data?
        include GlobalDataInstanceMethods
      elsif offroad_sync_data?
        include SyncDataInstanceMethods
      end
      include CommonInstanceMethods

      before_destroy :before_mirrored_data_destroy
      after_destroy :after_mirrored_data_destroy
      before_save :before_mirrored_data_save
      after_save :after_mirrored_data_save
    end

    def offroad_model_state
      model_scope = Offroad::ModelState::for_model(self)
      return model_scope.first || model_scope.create
    end

    def acts_as_offroadable?
      respond_to? :offroad_mode
    end

    def safe_to_load_from_cargo_stream?
      acts_as_offroadable?
    end

    def offroad_group_base?
      acts_as_offroadable? && offroad_mode == :group_base
    end

    def offroad_group_data?
      acts_as_offroadable? && OFFROAD_GROUP_MODES.include?(offroad_mode)
    end

    def offroad_global_data?
      acts_as_offroadable? && offroad_mode == :global
    end

    def offroad_sync_data?
      acts_as_offroadable? && offroad_mode == :naive_sync
    end

    private

    def set_internal_cattr(name, value)
      write_inheritable_attribute name, value
      class_inheritable_reader name
    end

    def args_for_ownership_scope(group)
      included_assocs = []
      conditions = []
      assoc_owner = self
      assoc = offroad_parent_assoc
      while true
        if assoc.klass.offroad_group_base?
          conditions << "`#{assoc_owner.table_name}`.`#{assoc.primary_key_name}` = #{group.id}"
          break
        else
          conditions << "`#{assoc_owner.table_name}`.`#{assoc.primary_key_name}` = `#{assoc.klass.table_name}`.`#{assoc.klass.primary_key}`"
          included_assocs << assoc
          assoc_owner = assoc.klass
          assoc = assoc.klass.offroad_parent_assoc
        end
      end

      # FIXME: It doesn't seem like the conditions are being generated quite right

      includes = {}
      included_assocs.reverse.each do |assoc|
        includes = {assoc.name => includes}
      end

      return {:include => includes, :conditions => conditions.join(" AND ")}
    end

    module GroupDataInstanceMethods
      def locked_by_offroad?
        Offroad::app_online? && group_offline?
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
          :operating_system
        ]
        return fields_of_interest.map {|field_name| s.send(field_name)}
      end

      def group_offline?
        not group_online?
      end

      def group_online?
        return group_state.nil?
      end

      def group_offline=(b)
        raise DataError.new("Unable to change a group's offline status in offline app") if Offroad::app_offline?
        if b && !group_state
          Offroad::GroupState.for_group(owning_group).create!
        elsif group_state
          group_state.destroy
        end
      end

      def owning_group
        # Recurse upwards until we get to the group base
        if self.class.offroad_group_base?
          return self
        else
          parent = send(offroad_parent_assoc.name)
          if parent
            return parent.owning_group
          else
            return nil
          end
        end
      end

      # Methods below this point are only to be used internally by Offroad
      # However, marking them private makes using them from elsewhere in the plugin troublesome

      #:nodoc#
      def before_mirrored_data_destroy
        if group_offline? && offroad_mode == :group_base
          group_state.update_attribute(:group_being_destroyed, true)
        end

        return true if checks_bypassed?

        if group_offline?
          # If the app is online, the only thing that can be deleted is the entire group (possibly with its records)
          # If the app is offline, the only thing that CAN'T be deleted is the group
          raise ActiveRecord::ReadOnlyRecord if Offroad::app_offline? and offroad_mode == :group_base
          raise ActiveRecord::ReadOnlyRecord if Offroad::app_online? and offroad_mode != :group_base and !group_being_destroyed
        end

        return true
      end

      #:nodoc#
      def after_mirrored_data_destroy
        Offroad::SendableRecordState::note_record_destroyed(self) if Offroad::app_offline?
        Offroad::GroupState::note_group_destroyed(self) if group_offline? && offroad_mode == :group_base
        return true
      end

      #:nodoc#
      def before_mirrored_data_save
        return true if checks_bypassed?

        raise DataError.new("Invalid owning group") if owning_group == nil
        raise ActiveRecord::ReadOnlyRecord if locked_by_offroad?

        if Offroad::app_offline?
          case offroad_mode
          when :group_base
            raise DataError.new("Cannot create groups in offline mode") if new_record?
          when :group_owned
            raise DataError.new("Owning group must be the offline group") if owning_group != Offroad::offline_group
          end
        end

        validate_changed_id_columns
        return true
      end

      #:nodoc#
      def after_mirrored_data_save
        if Offroad::app_offline?
          # Make a GroupState if this is the group being loaded into the offline app from an initial down mirror file
          if self.class.offroad_group_base? && group_state == nil
            GroupState.for_group(self).create!
          end

          Offroad::SendableRecordState::note_record_created_or_updated(self) if changed?
        end
        return true
      end

      #:nodoc#
      def group_state
        Offroad::GroupState.for_group(owning_group).first
      end

      #:nodoc:#
      def group_being_destroyed
        return true unless owning_group # If the group doesn't exist anymore, then it's pretty well destroyed
        return group_state.group_being_destroyed
      end
    end

    module GlobalDataInstanceMethods
      # Methods below this point are only to be used internally by Offroad
      # However, marking all of them private would make using them from elsewhere in the plugin troublesome

      #:nodoc#
      def before_mirrored_data_destroy
        return true if checks_bypassed?
        ensure_online
        return true
      end

      #:nodoc#
      def after_mirrored_data_destroy
        Offroad::SendableRecordState::note_record_destroyed(self) if Offroad::app_online?
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
        Offroad::SendableRecordState::note_record_created_or_updated(self) if Offroad::app_online? && changed?
        return true
      end

      private

      def ensure_online
        # Only the online app can change global data
        raise ActiveRecord::ReadOnlyRecord if Offroad::app_offline?
      end
    end

    module SyncDataInstanceMethods
      # Methods below this point are only to be used internally by Offroad
      # However, marking them private makes using them from elsewhere in the plugin troublesome

      #:nodoc#
      def before_mirrored_data_destroy
        #return true if checks_bypassed?
        return true
      end

      #:nodoc#
      def after_mirrored_data_destroy
        Offroad::SendableRecordState::note_record_destroyed(self)
        return true
      end

      #:nodoc#
      def before_mirrored_data_save
        return true if checks_bypassed?
        validate_changed_id_columns
        return true
      end

      #:nodoc#
      def after_mirrored_data_save
        Offroad::SendableRecordState::note_record_created_or_updated(self) if changed?
        return true
      end
    end

    module CommonInstanceMethods
      # Methods below this point are only to be used internally by Offroad
      # However, making all of them private would make using them from elsewhere in the plugin troublesome

      # TODO Should put common save and destroy wrappers in here, with access to a method that checks if SRS needed
      # TODO That method should also be used in import_model_cargo instead of explicitly trying to find the srs

      #:nodoc:#
      def bypass_offroad_readonly_checks
        @offroad_readonly_bypassed = true
      end

      #:nodoc:#
      def checks_bypassed?
        if @offroad_readonly_bypassed
          @offroad_readonly_bypassed = false
          return true
        end
        return false
      end

      #:nodoc:#
      def validate_changed_id_columns
        changes.each do |colname, arr|
          orig_val = arr[0]
          new_val = arr[1]

          raise DataError.new("Cannot change id of offroad-tracked records") if colname == self.class.primary_key

          # FIXME : Use association reflection instead
          next unless colname.end_with? "_id"
          accessor_name = colname[0, colname.size-3]
          next unless respond_to? accessor_name
          obj = send(accessor_name)

          raise DataError.new("Mirrored data cannot hold a foreign key to unmirrored data") unless obj.class.acts_as_offroadable?

          if !new_record? and offroad_mode == :group_owned and colname == offroad_parent_assoc.primary_key_name
            # obj is our parent
            # FIXME: What if we can't find orig_val?
            if obj.owning_group != obj.class.find(orig_val).owning_group
              raise DataError.new("Group-owned data cannot be transferred between groups")
            end
          end

          if self.class.offroad_group_data?
            if obj.class.offroad_group_data? && obj.owning_group.id != owning_group.id
              raise DataError.new("Invalid #{colname}: Group data cannot hold a foreign key to data owned by another group")
            end
          elsif self.class.offroad_global_data?
            unless obj.class.offroad_global_data?
              raise DataError.new("Invalid #{colname}: Global mirrored data cannot hold a foreign key to group data")
            end
          end
        end
      end
    end
  end
end
