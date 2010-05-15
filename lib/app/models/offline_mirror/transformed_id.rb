module OfflineMirror
	class TransformedId < ActiveRecord::Base
		set_table_name "offline_mirror_transformed_ids"

		belongs_to :group_model_pairing
	end
end
