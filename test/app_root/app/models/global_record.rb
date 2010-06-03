class GlobalRecord < ActiveRecord::Base
  acts_as_mirrored_offline :global
  validates_presence_of :title
end