module OfflineBridge
	class GroupModelPairing < ActiveRecord::Base
		set_table_name "offline_bridge_group_model_pairings"

		belongs_to :group_state
		belongs_to :model_state
		has_many :transformed_ids
	end
end
