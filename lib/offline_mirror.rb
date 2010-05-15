# OfflineMirror

require 'model_extensions'
class ActiveRecord::Base
	extend OfflineMirror::ModelExtensions
end

%w{ models workers }.each do |dir|
	path = File.join(File.dirname(__FILE__), 'app', dir)
	$LOAD_PATH << path
	ActiveSupport::Dependencies.load_paths << path
	ActiveSupport::Dependencies.load_once_paths.delete(path)
end

module OfflineMirror
	def self.app_offline?
		RAILS_ENV == "offline"
	end
	
	def self.app_online?
		not app_offline?
	end
	
	def self.app_version
		# TODO Implement
		# Online - When app is launched, scan all application files, this is the timestamp of the most recently changed file
		# Offline - Based on the app version noted in the last down-mirror file
		return 1
	end
	
	def self.launcher_version
		raise "Launcher is not a part of the online app" if app_online?
		# TODO Implement
		return 1
	end
	
	#:nodoc#
	def self.init
		@@config = YAML.load_file(File.join(RAILS_ROOT, "config", "offline_mirror.yml"))
	rescue
		@@config = {}
	end
	
	private
	
	def self.current_group_id
		raise "The current_group_id config value is only meaningful if the app is offline" unless app_offline?
		@@config[:offline_group_id] or raise "No offline group id specified in config"
	end

	def self.online_url
		@@config[:online_url] or raise "No online url specified in config"
	end
	
	def self.note_global_data_model(cls)
		@@global_data_models ||= []
		@@global_data_models << cls
	end
	
	def self.global_data_models
		@@global_data_models || []
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
		@@group_owned_models ||= []
		@@group_owned_models << cls
	end
	
	def self.group_owned_models
		@@group_owned_models || []
	end
end

OfflineMirror::init

# TODO
# - Write a generator for making a mirror controller scaffold
# - Only allow one mirror load operation at a time for a given group, and use transactions 
# - Creating/updating the installer (ideally, git to target platform, one rake task, then upload back to original server)
# - Intercept group deletions, drop corresponding group_state
# - When processing migrations, watch for table drops and renames; do corresponding change in table_states
# - When generating upmirror files, include ALL records on tables w/o lock_version (since client clock may be unreliable)
# - When applying upmirror files, use all supplied permission checks and also check to make sure object being changed belongs to logged-in user's group
# - The launcher should keep a log file
# - Include recent log lines (for both Rails and the launcher) in generated up-mirror files, for debugging purposes
# - Support use of several comparison columns, defined by model, used in descending order upon equality. Here should be the defaults:
	# - If app is online, then uses "lock_version, updated_at" if lock_version available, otherwise uses "updated_at"
	# - If app is offline, uses "lock_version" if available, otherwise uses nothing (so all records always considered dirty)
# - Take an md5sum of mirror data and include it for verification
# - Use rails logger to note activity
