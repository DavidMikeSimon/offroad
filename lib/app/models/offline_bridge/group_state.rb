module OfflineBridge
	class GroupState < ActiveRecord::Base
		set_table_name "offline_bridge_group_states"
		
		has_many :group_model_pairings
		
		validates_presence_of :app_group_id
		
		def self.find_by_group(obj, opts = {})
			ensure_group_base_model(obj)
			find_by_app_group_id(obj.id, opts)
		end
		
		def self.find_or_create_by_group(obj, opts = {})
			ensure_group_base_model(obj)
			find_or_create_by_app_group_id(obj.id, opts)
		end
		
		private
		
		def self.ensure_group_base_model(obj)
			raise "Passed object is not a group_base_model" unless obj.offline_bridge_mode == :group_base_model
		end
	end
end
