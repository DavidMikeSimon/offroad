module OfflineMirror
	private
	
	class SendableRecord < ActiveRecord::Base
		set_table_name "offline_mirror_sendable_records"
		
		belongs_to :group_state
		belongs_to :model_state
		
		def self.note_record_destroyed(group, model, local_id)
			rec = find_or_initialize_by_gri(group, model, local_id)
			rec.mirror_version = OfflineMirror::SystemState::current_mirror_version
			rec.local_record_id = 0
			rec.save!
		end
		
		def self.note_record_created_or_updated(group, model, local_id)
			rec = find_or_initialize_by_gri(group, model, local_id)
			rec.mirror_version = OfflineMirror::SystemState::current_mirror_version
			rec.save!
		end
		
		def self.find_or_initialize_by_gri(group, model, local_id)
			model_state_id = OfflineMirror::ModelState::find_or_create_by_model(model).id
			rec = find(:first, :conditions => {
				:model_state_id => model_state_id,
				:local_record_id => local_id
			})
			if rec
				return rec
			else
				group_state = group ? OfflineMirror::GroupState::find_or_create_by_group(group) : nil
				group_state_id = group_state ? group_state.id : 0 # 0 instead of nil because many databases have weird behaviour re: NULL and UNIQUE
				return new(
					:group_state_id => group_state_id,
					:model_state_id => model_state_id,
					:local_record_id => local_id,
					:remote_record_id => 0,
					:mirror_version => OfflineMirror::SystemState::current_mirror_version
				)
			end
		end
	end
end
