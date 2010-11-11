require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to correctly ignore unmirrored data

class UnmirroredDataTest < Test::Unit::TestCase
  agnostic_test "unmirrored data model returns false to acts_as_offroadable?" do
    assert_equal false, UnmirroredRecord.acts_as_offroadable?
  end
  
  agnostic_test "offroad_*_data? methods return false on unmirrored data models" do
    assert_equal false, UnmirroredRecord.offroad_group_data?
    assert_equal false, UnmirroredRecord.offroad_global_data?
  end
end
