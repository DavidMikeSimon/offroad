# OfflineMirror

require 'module_funcs'
require 'cargo_file'

%w{ models controllers }.each do |dir|
	path = File.join(File.dirname(__FILE__), 'app', dir)
	$LOAD_PATH << path
	ActiveSupport::Dependencies.load_paths << path
	ActiveSupport::Dependencies.load_once_paths.delete(path)
end

require 'model_extensions'
class ActiveRecord::Base
	extend OfflineMirror::ModelExtensions
end

require 'view_helper'
class ActionView::Base
	include OfflineMirror::ViewHelper
end

OfflineMirror::init

# TODO
# - Use transactions for mirror load operations
# - Creating/updating the installer (ideally, git to target platform, one rake task, then upload back to original server)
# - Intercept group deletions, drop corresponding group_state
# - When processing migrations, watch for table drops and renames; do corresponding change in table_states
# - When applying upmirror files, use all supplied permission checks and also check to make sure object being changed belongs to logged-in user's group
# - The launcher should keep a log file
# - Include recent log lines (for both Rails and the launcher) in generated up-mirror files, for debugging purposes
# - For group data: Support use of several versioning columns, defined by model. Default is whatever's available of [:lock_version, :updated_at]
	# - Include record whenever versioning column data is *different*, not just if it's higher
	# - When app is offline, the updated_at columns is never used (offline clock might not be reliable)
	# - If no versioning columns present, issue a single warning and then always treat records as dirty
# - For global data: Always and only use updated_at if available, compare with date of last *confirmed* *received* down mirror for that group
	# - If any records updated_at the same time as the down mirror's date, mark them for forced re-retrieval next down mirror (to prevent async losses)
	# - If no versioning columns present, issue a single warning and then always treat records as dirty
# - Properly deal with a new app version changing version column definition for one or more models (check against version_columns field)
# - Use rails logger to note activity
# - Document that the id of the group model itself is _never_ transformed, but all group_owned models and global models do have their id's transformed
# - Scenario to deal with: offline app applies an initial down mirror, then makes local changes, then attempts to reapply _another_ initial down mirror
	# - To deal with this, just ignore all non-global records in the second initial down mirror, since they should be identical
