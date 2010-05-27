module OfflineMirror
	private

	class GroupState < ActiveRecord::Base
		set_table_name "offline_mirror_group_states"
		
		has_many :group_model_pairings
		
		validates_presence_of :app_group_id
		
		def self.find_by_group(obj, opts = {})
			ensure_group_base_model(obj)
			find_by_app_group_id(obj.id, opts)
		end
		
		def self.find_or_create_by_group(obj, opts = {})
			ensure_group_base_model(obj)
			rec = find_or_initialize_by_app_group_id(obj.id, opts)
			if app_offline?
				# FIXME : Fill in last_installation_at, launcher_version, app_version
				rec.last_known_offline_os = RUBY_PLATFORM
				rec.offline = true
			end
			rec.save!
		end
		
		private
		
		def self.ensure_group_base_model(obj)
			raise "Passed object is not of a group_base_model" unless obj.class !== Class and obj.offline_mirror_mode == :group_base
		end
	end
end
