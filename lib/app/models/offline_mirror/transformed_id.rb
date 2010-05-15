module OfflineBridge
	class TransformedId < ActiveRecord::Base
		set_table_name "offline_bridge_transformed_ids"

		belongs_to :group_model_pairing
	end
end
