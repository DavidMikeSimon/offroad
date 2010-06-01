class Group < ActiveRecord::Base
  acts_as_mirrored_offline :group_base
  validates_presence_of :name
end
