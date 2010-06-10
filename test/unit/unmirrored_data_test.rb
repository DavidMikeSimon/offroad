require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to correctly ignore unmirrored data

class UnmirroredDataTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  common_test "unmirrored data model returns false to acts_as_mirrored_offline?" do
    assert_equal false, UnmirroredRecord.acts_as_mirrored_offline?
  end
  
  common_test "cannot call offline_mirror_*_data? on unmirrored data models" do
    assert_raise OfflineMirror::ModelError, "Expect exception on check for *group* data" do
      UnmirroredRecord.offline_mirror_group_data?
    end
    assert_raise OfflineMirror::ModelError, "Expect exception for check on *global* data" do
      UnmirroredRecord.offline_mirror_global_data?
    end
  end
end

run_test_class UnmirroredDataTest