require 'forwardable'

module OfflineMirror
  private
  
  # State of the OfflineMirror plugin as a whole; there should only be one record in this table
  # Attributes of that record can be read via the class methods of this class
  class SystemState < ActiveRecord::Base
    set_table_name "offline_mirror_system_state"
    
    # Create validators and class-level attribute getters for the columns that contain system settings
    extend SingleForwardable
    for column in columns
      sym = column.name.to_sym
      next if sym == :id
      def_delegator :instance_record, sym
    end
    
    # Do not allow use of global_data_version in SystemState in offline app
    # It needs to exclusively use the global_data_version in its GroupState record
    def global_data_version
      raise PluginError.new("Offline app not to use SystemState::global_data_version") unless OfflineMirror::app_online?
      super
    end
    
    def global_data_version=(new_val)
      raise PluginError.new("Offline app not to use SystemState::global_data_version") unless OfflineMirror::app_online?
      super(new_val)
    end
    
    # Returns the singleton record, first creating it if necessary
    def self.instance_record
      sys_state = first
      if sys_state
        return sys_state
      else
        if OfflineMirror::app_offline?
          raise OfflineMirror::DataError.new("Cannot auto-generate system settings on offline app")
        end
        return create(:global_data_version => 1, :offline_group_id => 0)
      end
    end
  end
end