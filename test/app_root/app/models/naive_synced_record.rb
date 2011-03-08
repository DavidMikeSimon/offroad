class NaiveSyncedRecord < ActiveRecord::Base
  acts_as_offroadable :naive_sync
  belongs_to :unmirrored_record
end
