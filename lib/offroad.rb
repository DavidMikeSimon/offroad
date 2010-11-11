# Offroad

require 'module_funcs'

require 'cargo_streamer'
require 'exceptions'
require 'mirror_data'

%w{ models controllers }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.load_paths << path
end

require 'model_extensions'
class ActiveRecord::Base
  extend Offroad::ModelExtensions
end

require 'view_helper'
class ActionView::Base
  include Offroad::ViewHelper
end

Offroad::init
