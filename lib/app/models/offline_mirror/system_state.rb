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
      validates_presence_of sym
      def_delegator :instance_record, sym
    end
    
    # Returns the singleton record, first creating it if necessary
    def self.instance_record
      sys_state = first
      if sys_state
        return sys_state
      else
        raise "Cannot auto-generate system settings on offline app" if OfflineMirror::app_offline?
        return create(:current_mirror_version => 1)
      end
    end
  end
end
