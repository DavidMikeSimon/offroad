require 'forwardable'

module OfflineMirror
  private
  
  # State of the OfflineMirror plugin as a whole; there should only be one record in this table
  # Attributes of that record can be read via the class methods of this class
  class SystemState < ActiveRecord::Base
    set_table_name "offline_mirror_system_state"
    
    # Create class methods: attribute getters for the columns that contain system settings
    extend SingleForwardable
    for column in content_columns
      def_delegator :instance_record, column.name.to_sym
    end
    
    # Returns the singleton record, first creating it if necessary
    def self.instance_record
      sys_state = first
      if sys_state
        return sys_state
      else
        current_mirror_version = OfflineMirror::app_online? ? 1 : (OfflineMirror::offline_group_state.up_mirror_version + 1)
        return create(:current_mirror_version => current_mirror_version)
      end
    end
  end
end
