class GroupOwnedRecord < ActiveRecord::Base
  acts_as_offroadable :group_owned, :group_key => :group_id
  belongs_to :group
  belongs_to :parent, :class_name => "GroupOwnedRecord"
  belongs_to :unmirrored_record
  belongs_to :global_record
  has_many :children, :foreign_key => "parent_id", :class_name => "GroupOwnedRecord"
  validates_presence_of :description, :group
  validates_numericality_of :should_be_even, :even => true
  attr_protected :protected_integer
  
  def to_s
    description
  end
end
