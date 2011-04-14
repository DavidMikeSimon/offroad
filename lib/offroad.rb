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
# Monkey patch a bug in ar-extensions which breaks postgres compatibility
module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    class AbstractAdapter # :nodoc:
      def next_value_for_sequence(sequence_name)
        %{nextval('#{sequence_name}')}
      end
    end
  end
end


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
