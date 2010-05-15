# OfflineMirror

require 'model_extensions'
class ActiveRecord::Base
	extend OfflineMirror::ModelExtensions
end

module OfflineMirror
	def app_offline?
		RAILS_ENV == "offline"
	end
	
	def app_online?
		not app_offline?
	end
	
	private
	
	class Internal
		def self.init
			@@config = YAML.load_file(File.join(RAILS_ROOT, "config", "offline_mirror.yml"))
		rescue
			@@config = {}
		end
		
		def self.current_group_id
			@@config[:offline_group_id] or raise "No offline group id specified in config"
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
end

OfflineMirror::Internal::init

%w{ models controllers }.each do |dir|
	path = File.join(File.dirname(__FILE__), 'app', dir)
	$LOAD_PATH << path
	ActiveSupport::Dependencies.load_paths << path
	ActiveSupport::Dependencies.load_once_paths.delete(path)
end

# TODO
# - Write a generator for making a mirror controller scaffold; have that controller inherit from a base controller which has all the actual guts that don't need configuration
# - Only allow one mirror operation at a time for a given group; make sure this can recover from mid-mirror crashes; do mirror ops in background
# - Creating/updating the installer (ideally, git to target platform, one rake task, then upload back to original server)
# - Intercept group deletions, drop corresponding group_state
# - When processing migrations, watch for table drops and renames; do corresponding change in table_states
# - When generating mirror files, include all new records, notes about all deleted records, and any records with newer updated_at or lock_version
# - When applying upmirror files, use all supplied permission checks and also check to make sure object being changed belongs to logged-in user's group
# - The launcher should keep a log file
# - Include recent log lines (for both Rails and the launcher) in generated up-mirror files, for debugging purposes
