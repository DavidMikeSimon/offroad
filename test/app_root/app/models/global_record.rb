class GlobalRecord < ActiveRecord::Base
  acts_as_mirrored_offline :global
  validates_presence_of :title
  belongs_to :unmirrored_record
  belongs_to :some_group, :class_name => "Group"
  belongs_to :friend, :class_name => "GlobalRecord"
end