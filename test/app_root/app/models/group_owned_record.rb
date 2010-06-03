class GroupOwnedRecord < ActiveRecord::Base
  acts_as_mirrored_offline :group_owned, :group_key => :group
  belongs_to :group
  validates_presence_of :description, :group
end