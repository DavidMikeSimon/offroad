class SubRecord < ActiveRecord::Base
  belongs_to :group_owned_record
  acts_as_offroadable :group_owned, :parent => :group_owned_record

  def to_s
    description
  end
end
