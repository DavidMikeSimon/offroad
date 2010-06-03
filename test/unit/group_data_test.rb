require File.dirname(__FILE__) + '/../test_helper'

class GroupDataTest < ActiveSupport::TestCase
  def create_online_group_and_data
    online_group = Group.create(:name => "An Online Group")
    online_group_data = GroupOwnedRecord.create(:description => "Some Online Data", :group => online_group)
    return [online_group, online_group_data]
  end
  
  def create_offline_group_and_data
    offline_group = Group.create(:name => "An Offline Group")
    offline_group.group_offline = true
    offline_group_data = GroupOwnedRecord.create(:description => "Some Offline Data", :group => offline_group)
    return [offline_group, offline_group_data]
  end
  
  common_test :a_new_group_is_online_by_default do
    g = Group.create(:name => "This Should Be Online")
    assert g.group_online?, "Newly created group should be online"
  end
  
  common_test :group_data_has_expected_offline_status do
    online_group, online_group_data = create_online_group_and_data
    assert online_group.group_online?, "Groups which are in online mode should return true to group_online?"
    assert_equal false, online_group.group_offline?, "Groups in online mode should return false to group_offline?"
    assert online_group_data.group_online?, "Data belonging to groups which are in online mode should return true to group_online?"
    assert_equal false, online_group_data.group_offline?, "Data belonging to groups in online mode should return false to group_offline?"
    
    offline_group, offline_group_data = create_offline_group_and_data
    assert offline_group.group_offline?, "Groups which have been set offline should return true to group_offline?"
    assert_equal false, offline_group.group_online?, "Groups which have been set offline should return false to group_online?"
    assert offline_group_data.group_offline?, "Data belonging to groups which have been set offline should return true to group_offline?"
    assert_equal false, offline_group_data.group_online?, "Data belonging to groups which have been set offline should return false to group_online?"
  end
  
  common_test :group_data_models_report_having_group_data do
    assert Group.offline_mirror_group_data?, "Group model should return true to offline_mirror_group_data?"
    assert_equal false, Group.offline_mirror_global_data?, "Group model should return false to offline_mirror_global_data?"
    
    assert GroupOwnedRecord.offline_mirror_group_data?, "GroupData model should return true to offline_mirror_group_data?"
    assert_equal false, GroupOwnedRecord.offline_mirror_global_data?, "GroupData model should return false to offline_mirror_global_data?"
  end
  
  online_test :only_offline_group_data_models_locked_in_online_app do
  end
  
  offline_test :offline_group_data_models_not_locked_in_offline_app do
  end
end

run_test_class GroupDataTest
