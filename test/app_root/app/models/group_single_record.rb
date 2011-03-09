class GroupSingleRecord < ActiveRecord::Base
  acts_as_offroadable :group_single

  def to_s
    description
  end
end
