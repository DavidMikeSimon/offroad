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
