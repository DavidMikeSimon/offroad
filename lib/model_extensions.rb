module OfflineMirror
	module ModelExtensions
		OFFLINE_MIRROR_VALID_MODES = [:group_base, :group_owned, :global]
		OFFLINE_MIRROR_GROUP_MODES = [:group_base, :group_owned]
		
		def acts_as_mirrored_offline(mode, opts = {})
			raise "You can only call acts_as_mirrored_offline once per model" if respond_to? :offline_mirror_mode
			raise "You must specify a mode, one of " + OFFLINE_MIRROR_VALID_MODES.map(&:inspect).join("/") unless OFFLINE_MIRROR_VALID_MODES.include?(mode)
			
			set_internal_cattr :offline_mirror_mode, mode
			
			set_internal_cattr :offline_mirror_permission_checkers, {}
			[:create_permitted?, :update_permitted?, :delete_permitted?].each do |o|
				if opts[o]
					raise "Can't specify " + inspect(o) + " for non-group models" unless OFFLINE_MIRROR_GROUP_MODES.include?(mode)
					# FIXME: Make use of these when loading mirror data
					offline_mirror_permission_checkers[o] = opts.delete(o)
				end
			end
			
			case mode
			when :group_owned then
				raise "For :group_owned_model, need to specify :group_key, an attribute name for this model's owning group" unless opts[:group_key]
				begin
					raise "The :group_key is invalid, there's no column with that name" unless columns.include?(opts[:group_key].to_s)
				rescue
					unless opts[:group_key].to_s.end_with?("_id")
						opts[:group_key] = opts[:group_key].to_s + "_id"
						retry
					end
				end
				OfflineMirror::note_group_owned_model(self)
				set_internal_cattr :offline_mirror_group_key, opts.delete(:group_key).to_sym
			when :group_base then
				OfflineMirror::note_group_base_model(self)
			when :global then
				OfflineMirror::note_global_data_model(self)
			end
			
			# We should have deleted all the options from the hash by this point
			raise "Unknown or inapplicable option(s) specified" unless opts.size == 0
			
			if OFFLINE_MIRROR_GROUP_MODES.include?(mode)
				include GroupDataInstanceMethods
			else
				include GlobalDataInstanceMethods
			end
			before_destroy :check_mirrored_data_destroy
			before_save :check_mirrored_data_save
		end
		
		private
		
		def set_internal_cattr(name, value)
			write_inheritable_attribute name, value
			class_inheritable_reader name
		end
		
		# Only the online app can change global data
		module GlobalDataInstanceMethods
			def check_mirrored_data_destroy
				ensure_online
			end
			
			def check_mirrored_data_save
				ensure_online
			end
			
			private
			
			def ensure_online
				raise ActiveRecord::ReadOnlyRecord if OfflineMirror::app_offline?
			end
		end
		
		module GroupDataInstanceMethods
			def locked_by_offline_mirror?
				group_offline? && app_online?
			end
			
			# If called on a group_owned_model, methods below bubble up to the group_base_model
			
			def last_known_status
				raise "This method is only for offline group data accessed from an online app" unless locked_by_offline_mirror?
				s = group_state
				fields_of_interest = [
					:offline,
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
				group_state.offline?
			end
			
			def group_online?
				not group_state.offline?
			end
			
			def group_offline=(b)
				group_state.update_attribute(:offline, b)
			end
			
			def owning_group
				case offline_mirror_mode
					when :group_owned then OfflineMirror::group_base_model.find_by_id(self.send offline_mirror_group_key)
					when :group_base then self
					else raise "Unable to find owning group"
				end
			end
			
			# Methods below this point are only to be used internally by OfflineMirror
			# However, marking them private makes using them from elsewhere in the plugin troublesome

			#:nodoc#
			def check_mirrored_data_destroy
				# If the group is offline but the app is online, the only thing that can be deleted is the entire group
				raise ActiveRecord::ReadOnlyRecord if (locked_by_offline_mirror? and offline_mirror_mode != :group_base)
			end
			
			#:nodoc#
			def check_mirrored_data_save
				raise ActiveRecord::ReadOnlyRecord if locked_by_offline_mirror?
				
				# If the app is offline, then we need to make sure that this record belongs to the group this offline instance of the app is for
				if app_offline?
					return group_state.app_group_id == OfflineMirror::offline_group_id
				end
			end
			
			#:nodoc#
			def group_state
				GroupState.find_or_create_by_group(owning_group)
			end
		end
		
		module GlobalDataInstanceMethods
		end
	end
end
