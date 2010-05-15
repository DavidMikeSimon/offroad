module OfflineMirror
	private

	# Note: the id of the group model itself is _never_ transformed, but all group_owned models and global models do have their id's transformed
	class TransformedId < ActiveRecord::Base
		set_table_name "offline_mirror_transformed_ids"

		belongs_to :group_model_pairing
	end
end
