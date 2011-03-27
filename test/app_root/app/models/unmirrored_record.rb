class UnmirroredRecord < ActiveRecord::Base
  include CommonHobo if HOBO_TEST_MODE
  validates_presence_of :content
end
