class NaiveSyncedRecord < ActiveRecord::Base
  acts_as_offroadable :naive_sync
  belongs_to :unmirrored_record
  belongs_to :global_record
  belongs_to :group
  belongs_to :group_owned_record
  belongs_to :buddy, :class_name => "NaiveSyncedRecord"
end
