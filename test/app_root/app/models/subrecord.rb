class SubRecord < ActiveRecord::Base
  hobo_model if HOBO_TEST_MODE
  belongs_to :group_owned_record
  acts_as_offroadable :group_owned, :parent => :group_owned_record

  belongs_to :buddy, :class_name => "SubRecord"
  belongs_to :unmirrored_record

  def to_s
    description
  end
end
