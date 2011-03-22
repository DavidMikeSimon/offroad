class UnmirroredRecord < ActiveRecord::Base
  hobo_model if HOBO_TEST_MODE
  validates_presence_of :content
end
