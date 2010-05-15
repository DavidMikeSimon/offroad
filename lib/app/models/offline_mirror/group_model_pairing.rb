module OfflineMirror
	class GroupModelPairing < ActiveRecord::Base
		set_table_name "offline_mirror_group_model_pairings"

		belongs_to :group_state
		belongs_to :model_state
		has_many :transformed_ids
	end
end
