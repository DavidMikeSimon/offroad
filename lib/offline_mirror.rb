# OfflineMirror

require 'module_funcs'
require 'cargo_streamer'

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
