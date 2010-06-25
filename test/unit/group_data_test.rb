require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to handle group data models

class GroupDataTest < Test::Unit::TestCase
  online_test "a new group is online by default" do
    g = Group.create(:name => "This Should Be Online")
    assert g.group_online?
  end
  
  offline_test "group is offline by default" do
    assert @offline_group.group_offline?
  end
  
  online_test "online group data has expected offline status" do
    assert @online_group.group_online?, "Groups which are in online mode should return true to group_online?"
    assert_equal false, @online_group.group_offline?, "Groups in online mode should return false to group_offline?"
    assert @online_group_data.group_online?, "Data belonging to groups which are in online mode should return true to group_online?"
    assert_equal false, @online_group_data.group_offline?, "Data belonging to groups in online mode should return false to group_offline?"
  end
  
  double_test "offline group data has expected offline status" do
    assert @offline_group.group_offline?, "Groups which have been set offline should return true to group_offline?"
    assert_equal false, @offline_group.group_online?, "Groups which have been set offline should return false to group_online?"
    assert @offline_group_data.group_offline?, "Data belonging to groups which have been set offline should return true to group_offline?"
    assert_equal false, @offline_group_data.group_online?, "Data belonging to groups which have been set offline should return false to group_online?"
  end
  
  double_test "group data models report being group data" do
    assert Group.offline_mirror_group_data?, "Group model should return true to offline_mirror_group_data?"
    assert_equal false, Group.offline_mirror_global_data?, "Group model should return false to offline_mirror_global_data?"
    
    assert GroupOwnedRecord.offline_mirror_group_data?, "Group-owned model should return true to offline_mirror_group_data?"
    assert_equal false, GroupOwnedRecord.offline_mirror_global_data?, "Group-owned model should return false to offline_mirror_global_data?"
  end
  
  double_test "group base reports being owned by itself" do
    assert_equal @offline_group.id, @offline_group.owning_group.id, "Can get offline group id thru owning_group dot id"
    assert_equal @offline_group.id, @offline_group.owning_group_id, "Can get offline group id thru owning_group_id"
  end
  
  double_test "group-owned data reports proper ownership" do
    assert_equal @offline_group.id, @offline_group_data.owning_group.id, "Can get owner id thru owning_group dot id"
    assert_equal @offline_group.id, @offline_group_data.owning_group_id, "Can get owner id thru owning_group_id"
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
    assert_raise OfflineMirror::DataError do
      Group.create(:name => "Another Offline Group?")
    end
  end
  
  offline_test "cannot destroy the group" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group.destroy
    end
  end
  
  offline_test "cannot change id of offline group data" do
    assert_raise OfflineMirror::DataError do
      @offline_group.id += 1
      @offline_group.save!
    end
    
    assert_raise OfflineMirror::DataError do
      @offline_group_data.id += 1
      @offline_group_data.save!
    end
  end
  
  online_test "cannot change id of online group data" do
    assert_raise OfflineMirror::DataError do
      @online_group.id += 1
      @online_group.save!
    end
    
    assert_raise OfflineMirror::DataError do
      @online_group_data.id += 1
      @online_group_data.save!
    end
  end
  
  offline_test "cannot set offline group to online" do
    assert_raise OfflineMirror::DataError do
      @offline_group.group_offline = false
    end
  end
  
  online_test "group data cannot hold a foreign key to a record owned by another group" do
    # This is an online test because the concept of "another group" doesn't fly in offline mode
    @another_group = Group.create(:name => "Another Group")
    @another_group_data = GroupOwnedRecord.create(:description => "Another Piece of Data", :group => @another_group)
    assert_raise OfflineMirror::DataError, "Expect exception when putting bad foreign key in group base data" do
      @online_group.favorite = @another_group_data
      @online_group.save!
    end
    assert_raise OfflineMirror::DataError, "Expect exception when putting bad foreign key in group owned data" do
      @online_group_data.parent = @another_group_data
      @online_group_data.save!
    end
  end
  
  double_test "group data can hold a foreign key to data owned by the same group" do
    assert_nothing_raised do
      more_data = GroupOwnedRecord.create(:description => "More Data", :group => @editable_group, :parent => @editable_group_data)
      @editable_group.favorite = more_data
      @editable_group.save!
    end
  end
  
  online_test "group data can hold a foreign key to global data" do
    # This is an online test because an offline app cannot create global records
    global_data = GlobalRecord.create(:title => "Some Global Data")
    assert_nothing_raised "No exception when putting global data key in group base data" do
      @editable_group.global_record = global_data
      @editable_group.save!
    end
    assert_nothing_raised "No exception when putting global data key in group owned data" do
      @editable_group_data.global_record = global_data
      @editable_group_data.save!
    end
  end
  
  double_test "group data cannot hold a foreign key to unmirrored data" do
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise OfflineMirror::DataError, "Expect exception when putting bad foreign key in group base data" do
      @editable_group.unmirrored_record = unmirrored_data
      @editable_group.save!
    end
    assert_raise OfflineMirror::DataError, "Expect exception when putting bad foreign key in group owned data" do
      @editable_group_data.unmirrored_record = unmirrored_data
      @editable_group_data.save!
    end
  end
  
  online_test "last_known_status is not available for online groups" do
    assert_raise OfflineMirror::DataError do
      status = @online_group.last_known_status
    end
  end
  
  double_test "last_known_status is available for offline groups" do
    status = @offline_group.last_known_status
    assert status
  end
  
  double_test "group data models return true to acts_as_mirrored_offline?" do
    assert Group.acts_as_mirrored_offline?, "Group reports mirrored offline"
    assert GroupOwnedRecord.acts_as_mirrored_offline?, "GroupOwnedRecord reports mirrored offline"
  end
  
  online_test "cannot save :group_owned data with an invalid group id" do
    assert_raise OfflineMirror::DataError do
      @offline_group_data.group_id = Group.maximum(:id)+1
      @offline_group_data.save(false) # Have to disable validations or it'll catch this error first
    end
  end
  
  online_test "cannot move :group_owned data from one group to another" do
    assert_raise OfflineMirror::DataError do
      @offline_group_data.group = @online_group
      @offline_group_data.save!
    end
  end
end