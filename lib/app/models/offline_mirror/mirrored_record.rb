module OfflineMirror
	private

	class MirroredRecord < ActiveRecord::Base
		set_table_name "offline_mirror_mirrored_records"

		belongs_to :group_model_pairing
	end
end
