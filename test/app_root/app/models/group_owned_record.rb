class GroupOwnedRecord < ActiveRecord::Base
  acts_as_mirrored_offline :group_owned, :group_key => :group
  belongs_to :group
  belongs_to :parent, :class_name => "GroupOwnedRecord"
  belongs_to :unmirrored_record
  belongs_to :global_record
  has_many :children, :class_name => "GroupOwnedRecord"
  validates_presence_of :description, :group
end