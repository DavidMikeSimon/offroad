# Offroad

require 'version'
require 'module_funcs'
require 'cargo_streamer'
require 'exceptions'
require 'mirror_data'

path = File.join(File.dirname(__FILE__), 'app', 'models')
$LOAD_PATH << path
ActiveSupport::Dependencies.autoload_paths << path

require 'ar-extensions' # External dependency

require 'controller_extensions'
class ActionController::Base
  extend Offroad::ControllerExtensions
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
