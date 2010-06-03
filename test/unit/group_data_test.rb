require File.dirname(__FILE__) + '/../test_helper'

class GroupDataTest < ActiveSupport::TestCase
  def setup
    if OfflineMirror::app_offline?
      opts = {
        :offline_group_id => 1,
        :current_mirror_version => 1
      }
      OfflineMirror::SystemState::create(opts) or raise "Unable to create offline-mode testing SystemState"
    end
    
    @offline_group = Group.create(:name => "An Offline Group")
    @offline_group_data = GroupOwnedRecord.create(:description => "Some Offline Data", :group => @offline_group)
    
    if OfflineMirror::app_online?
      @offline_group.group_offline = true
      
      @online_group = Group.create(:name => "An Online Group") # Will be online by default (tested below)
      @online_group_data = GroupOwnedRecord.create(:description => "Some Online Data", :group => @online_group)
    end
  end
  
  online_test "a new group is online by default" do
    g = Group.create(:name => "This Should Be Online")
    assert g.group_online?, "Newly created group should be online"
  end
  
  offline_test "group is offline by default" do
    assert @offline_group.group_offline?, "Newly created group should be offline"
  end
  
  online_test "online group data has expected offline status" do
    assert @online_group.group_online?, "Groups which are in online mode should return true to group_online?"
    assert_equal false, @online_group.group_offline?, "Groups in online mode should return false to group_offline?"
    assert @online_group_data.group_online?, "Data belonging to groups which are in online mode should return true to group_online?"
    assert_equal false, @online_group_data.group_offline?, "Data belonging to groups in online mode should return false to group_offline?"
  end
  
  common_test "offline group data has expected offline status" do
    assert @offline_group.group_offline?, "Groups which have been set offline should return true to group_offline?"
    assert_equal false, @offline_group.group_online?, "Groups which have been set offline should return false to group_online?"
    assert @offline_group_data.group_offline?, "Data belonging to groups which have been set offline should return true to group_offline?"
    assert_equal false, @offline_group_data.group_online?, "Data belonging to groups which have been set offline should return false to group_online?"
  end
  
  common_test "group data models report being group data" do
    assert Group.offline_mirror_group_data?, "Group model should return true to offline_mirror_group_data?"
    assert_equal false, Group.offline_mirror_global_data?, "Group model should return false to offline_mirror_global_data?"
    
    assert GroupOwnedRecord.offline_mirror_group_data?, "GroupData model should return true to offline_mirror_group_data?"
    assert_equal false, GroupOwnedRecord.offline_mirror_global_data?, "GroupData model should return false to offline_mirror_global_data?"
  end
  
  online_test "only offline groups locked and unsaveable" do
    assert @offline_group.locked_by_offline_mirror?, "Offline groups should be locked"
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group.save!
    end
    
    assert_equal false, @online_group.locked_by_offline_mirror?, "Online groups should not be locked"
    assert_nothing_raised do
      @online_group.save!
    end
  end
  
  online_test "only offline group owned data locked and unsaveable" do
    assert @offline_group_data.locked_by_offline_mirror?, "Offline group data should be locked"
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group_data.save!
    end
    
    assert_equal false, @online_group_data.locked_by_offline_mirror?, "Online group data should not be locked"
    assert_nothing_raised do
      @online_group_data.save!
    end
  end
  
  online_test "offline and online groups can both be destroyed" do
    assert_nothing_raised do
      @offline_group.destroy
    end
    
    assert_nothing_raised do
      @online_group.destroy
    end
  end
  
  online_test "only offline group owned data cannot be destroyed" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group_data.destroy
    end
    
    assert_nothing_raised do
      @online_group_data.destroy
    end
  end
  
  offline_test "offline groups unlocked and writable" do
    assert_equal false, @offline_group.locked_by_offline_mirror?
    assert_nothing_raised do
      @offline_group.save!
    end
  end
  
  offline_test "offline group owned data unlocked and writable" do
    assert_equal false, @offline_group_data.locked_by_offline_mirror?
    assert_nothing_raised do
      @offline_group_data.save!
    end
  end
  
  offline_test "offline group owned data destroyable" do
    assert_nothing_raised do
      @offline_group_data.destroy
    end
  end
  
  offline_test "cannot create another group" do
    assert_raise RuntimeError do
      Group.create(:name => "Another Offline Group?")
    end
  end
  
  offline_test "cannot destroy the group" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group.destroy
    end
  end
  
  common_test "cannot change id of group data" do
  end
  
  offline_test "cannot set offline group to online" do
    assert_raise RuntimeError do
      @offline_group.group_offline = false
    end
  end
end

run_test_class GroupDataTest
