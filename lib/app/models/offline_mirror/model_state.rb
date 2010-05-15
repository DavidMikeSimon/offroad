module OfflineMirror
	class ModelState < ActiveRecord::Base
		set_table_name "offline_mirror_model_states"
		
		has_many :group_model_pairings
		
		validates_presence_of :app_model_name
		
		def self.find_by_model(cls, opts = {})
			cls = classifize(cls) 
			ensure_group_base_model(cls)
			find_by_app_model_name(cls.to_s, opts)
		end
		
		def self.find_or_create_by_model(cls, opts = {})
			cls = classifize(cls) 
			ensure_group_base_model(cls)
			find_or_create_by_app_model_name(cls.to_s, opts)
		end
		
		private
		
		def self.classifize(obj)
			cls.class === Class ? cls : cls.class
		end
		
		def self.ensure_group_base_model(cls)
			raise "Passed class is not a group_base_model" unless cls.offline_mirror_mode == :group_base_model
		end
	end
end
