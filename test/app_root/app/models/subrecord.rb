class SubRecord < ActiveRecord::Base
  acts_as_offroadable :group_owned, :group_key => :group_owned_record_id
  belongs_to :group_owned_record

  def to_s
    description
  end
end
