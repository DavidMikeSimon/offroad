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
# - Use rails logger to note activity
# - Document that the id of the group model itself is _never_ transformed, but all group_owned models and global models do have their id's transformed
# - Scenario to deal with: offline app applies an initial down mirror, then makes local changes, then attempts to reapply _another_ initial down mirror
	# - To deal with this, just ignore all non-global records in the second initial down mirror, since they should be identical
# - Versioning the app : how to do this?
# - When we import first down mirror w/ group data, set current_mirror_version to up_mirror_version + 1. OfflineMirror::system_state tries to do this; test.
# - Make sure the filters catch typical ActiveRecord class methods: create, update, delete, etc.
# - Split the offline environment into 'offline-production' and 'offline-test'
# - Only update current_mirror_version after a confirmed transfer; that way, if 1st mirror file generated is lost, no big deal
# - Don't accept down-mirror or up-mirror files that are the same version as the one already in place; version number must be greater
	# - This causes problems if we aren't getting a nice back-and-forth of up-mirror and down-mirror, which is intentional
# - In online app, increment current_mirror_version whenever anyone confirms that they received a down mirror
# - In offline app, increment current_mirror_version whenever an up-mirror is confirmed
# - In documentation, note that migrations which change records' primary keys will break synchronization
