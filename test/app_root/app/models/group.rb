class Group < ActiveRecord::Base
  include CommonHobo if HOBO_TEST_MODE
  acts_as_offroadable :group_base
  validates_presence_of :name
  has_many :group_owned_records, :dependent => :destroy
  belongs_to :favorite, :class_name => "GroupOwnedRecord"
  belongs_to :unmirrored_record
  belongs_to :global_record
  def to_s
    name
  end
end
