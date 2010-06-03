require File.dirname(__FILE__) + '/../test_helper'

class GroupDataTest < ActiveSupport::TestCase
  common_test :groups_have_expected_offline_statuses do
    basic_group = Group.create(:name => "An Online Group")
    assert basic_group.group_online?, "Newly created groups should be online by default"
    assert_equal false, basic_group.group_offline?, "Newly created groups should not be offline"
    
    offline_group = Group.create(:name => "An Offline Group")
    offline_group.group_offline = true
    assert offline_group.group_offline?, "Groups which have been set offline should return true to group_offline?"
    assert_equal false, offline_group.group_online?, "Groups which have been set offline should return false to group_online?"
  end
  
  common_test :group_data_models_report_having_group_data do
    assert_equal true, Group.offline_mirror_group_data?, "Group model should return true to offline_mirror_group_data?"
    assert_equal false, Group.offline_mirror_global_data?, "Group model should return false to offline_mirror_global_data?"
    
    assert_equal true, GroupOwnedRecord.offline_mirror_group_data?, "GroupData model should return true to offline_mirror_group_data?"
    assert_equal false, GroupOwnedRecord.offline_mirror_global_data?, "GroupData model should return false to offline_mirror_global_data?"
  end
  
  online_test :only_offline_group_data_models_locked_in_online_app do
  end
end

run_test_class GroupDataTest
