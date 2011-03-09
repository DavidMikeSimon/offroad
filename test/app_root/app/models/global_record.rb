class GlobalRecord < ActiveRecord::Base
  acts_as_offroadable :global
  validates_presence_of :title
  belongs_to :unmirrored_record
  belongs_to :naive_synced_record
  belongs_to :some_group, :class_name => "Group"
  belongs_to :friend, :class_name => "GlobalRecord"
  validates_numericality_of :should_be_odd, :odd => true
  attr_protected :protected_integer
end
