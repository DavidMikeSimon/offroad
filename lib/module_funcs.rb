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
		# TODO Include schema information so that the online app can do an in-place migration of the data before importing it
	end
	
	def self.add_global_mirror_cargo(group, cargo_file)
		@@global_data_models.each do |name, cls|
			data = cls.connection.select_all("SELECT * FROM \"#{cls.table_name}\"")
			cargo_file.cargo_table["global_model_data_#{cls.name}"] = data
		end
		# TODO If this group has no confirmed down mirror, also include all group data
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
