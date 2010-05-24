module OfflineMirror
	VERSION_MAJOR = 0
	VERSION_MINOR = 1
	
	# Returns true if the app is in offline mode (running on a local system without access to the main server)
	def self.app_offline?
		RAILS_ENV == "offline"
	end
	
	# Returns true if the app is in online mode (or in other words, this is the main server)
	def self.app_online?
		not app_offline?
	end
	
	# Returns a Time that identifies the version of the app
	# Specifically, the modification timestamp (on the online app) of the most recently modified source file in the app
	def self.app_version
		# TODO Implement
		# Online - When app is launched, scan all application files. This function returns the Time of the most recently changed file
		# Offline - Based on the app version noted in the last down-mirror file successfully loaded
		return 1
	end
	
	#:nodoc#
	def self.init
		@@config = YAML.load_file(File.join(RAILS_ROOT, "config", "offline_mirror.yml"))
	rescue
		@@config = {}
	end
	
	# Returns the ID of the record of the group base model that this app is in charge of
	# This is only applicable if the app is offline
	def self.offline_group_id
		raise "'Offline group' is only meaningful if the app is offline" unless app_offline?
		@@config[:offline_group_id] or raise "No offline group id specified in config"
	end
	
	# Returns the record of the group base model that this app is in charge of
	# This is only applicable if the app is offline
	def self.offline_group
		@@group_base_model.find(offline_group_id)
	end
	
	private
	
	def self.system_state
		sys_state = OfflineMirror::SystemState::first
		if sys_state
			return sys_state
		else
			current_mirror_version = app_online? ? 1 : (offline_group_state.up_mirror_version + 1)
			return OfflineMirror::SystemState::create(:current_mirror_version => current_mirror_version)
		end
	end
	
	def self.offline_group_state
		OfflineMirror::GroupState::find_or_create_by_group(offline_group)
	end
	
	def self.add_group_specific_mirror_cargo(group, cargo_file)
		# FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
		# FIXME: Indicate what up-mirror version this is, and what migrations are applied
		# FIXME: Also allow for a full-sync mode (includes all records)
		group_owned_models.each do |name, cls|
			cargo_file["group_model_schema_#{name}"] = cls.columns
			
			# FIXME: Also include id transformation by joining with the mirrored_records table
			# FIXME: Check against mirror version
			# FIXME: Mark deleted records
			data = cls.find(:all, :conditions => { cls.offline_mirror_group_key.to_sym => group })
			cargo_file["group_model_data_#{name}"] = data.map(&:attributes)
		end
		
		cargo_file["group_state"] = group.group_state.attributes
		
		# Have to include the schema so all tables are available to pre-import migrations, even if we don't send any changes to this table
		cargo_file["group_model_schema_#{group_base_model.name}"] = group_base_model.columns
		# FIXME: Check against mirror version; don't include if there are no changes
		cargo_file["group_model_data_#{group_base_model.name}"] = group.attributes
	end
	
	def self.add_global_mirror_cargo(group, cargo_file)
		# FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
		# FIXME: Indicate what down-mirror version this is
		# FIXME: Also allow for a full-sync mode (includes all records)
		# FIXME: Include any changed files in the app, if necessary
		global_data_models.each do |name, cls|
			# No need to worry about id transformation global data models, it's not necessary
			# FIXME: Check against mirror version
			# FIXME: Mark deleted records
			cargo_file["global_model_data_#{name}"] = cls.all.map(&:attributes)
		end
		
		# If this group has no confirmed down mirror, also include all group data to be the offline app's initial state
		if group.group_state.down_mirror_version == 0
			add_group_specific_mirror_cargo(group, cargo_file)
		end
	end
	
	def self.online_url
		@@config[:online_url] or raise "No online url specified in offline mirror config"
	end
	
	def self.app_name
		@@config[:app_name] or raise "No app name specified in offline mirror config"
	end
	
	def self.note_global_data_model(cls)
		@@global_data_models ||= {}
		@@global_data_models[cls.name] = cls
	end
	
	def self.global_data_models
		@@global_data_models || {}
	end
	
	def self.note_group_base_model(cls)
		raise "You can only define one group base model" if defined?(@@group_base_model) and @@group_base_model.to_s != cls.to_s
		@@group_base_model = cls
	end
	
	def self.group_base_model
		raise "No group base model was specified" unless defined?(@@group_base_model)
		@@group_base_model
	end
	
	def self.note_group_owned_model(cls)
		@@group_owned_models ||= {}
		@@group_owned_models[cls.name] = cls
	end
	
	def self.group_owned_models
		@@group_owned_models || {}
	end
end
