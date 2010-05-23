module OfflineMirror
	private
	
	# State of this system as a whole; there should only be one record in this table
	# Retrieve that record through OfflineMirror::system_state
	class SystemState < ActiveRecord::Base
		set_table_name "offline_mirror_system_state"
	end
end
