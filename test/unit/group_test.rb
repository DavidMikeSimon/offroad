require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < ActiveSupport::TestCase
  common_test :groups_have_expected_offline_statuses do
    basic_group = Group.create(:name => "An Online Group")
    assert basic_group.group_online?, "Newly created groups should be online by default"
    assert_equal false, group.group_offline?, "Newly created groups should not be offline"
    
    offline_group = Gropu.create(:name => "An Offline Group")
    offline_group.group_offline = true
    assert offline_group.group_offline?, "Groups which have been set offline should return true to group_offline?"
    assert_equal false, offline_group.group_online?, "Groups which have been set offline should return false to group_online?"
  end
end

run_test_class GroupTest
