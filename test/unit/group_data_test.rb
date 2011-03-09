require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle group data models

class GroupDataTest < Test::Unit::TestCase
  online_test "a new group is online by default" do
    g = Group.create(:name => "This Should Be Online")
    assert g.group_online?
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
    assert Group.offroad_group_data?, "Group model should return true to offroad_group_data?"
    assert_equal false, Group.offroad_global_data?, "Group model should return false to offroad_global_data?"
    
    assert GroupOwnedRecord.offroad_group_data?, "Group-owned model should return true to offroad_group_data?"
    assert_equal false, GroupOwnedRecord.offroad_global_data?, "Group-owned model should return false to offroad_global_data?"
  end
  
  double_test "group base reports being owned by itself" do
    assert_equal @offline_group.id, @offline_group.owning_group.id, "Can get offline group id thru owning_group dot id"
  end
  
  double_test "group-owned data reports proper ownership" do
    assert_equal @offline_group.id, @offline_group_data.owning_group.id, "Can get owner id thru owning_group dot id"
  end

  double_test "indirectly group-owned data reports proper ownership" do
    assert_equal @offline_group.id, @offline_indirect_data.owning_group.id, "Can get owner id through owning_group dot id"
  end
  
  online_test "only offline groups locked and unsaveable" do
    assert @offline_group.locked_by_offroad?, "Offline groups should be locked"
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group.save!
    end
    
    assert_equal false, @online_group.locked_by_offroad?, "Online groups should not be locked"
    assert_nothing_raised do
      @online_group.save!
    end
  end
  
  online_test "only offline group owned data locked and unsaveable" do
    assert @offline_group_data.locked_by_offroad?, "Offline group data should be locked"
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group_data.save!
    end
    
    assert_equal false, @online_group_data.locked_by_offroad?, "Online group data should not be locked"
    assert_nothing_raised do
      @online_group_data.save!
    end
  end
  
  online_test "only offline group indirect data locked and unsaveable" do
    assert @offline_indirect_data.locked_by_offroad?, "Offline indirect data should be locked"
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_indirect_data.save!
    end
    
    assert_equal false, @online_indirect_data.locked_by_offroad?, "Online indirect data should not be locked"
    assert_nothing_raised do
      @online_indirect_data.save!
    end
  end

  online_test "can find online and offline groups through scope" do
    another = Group.create(:name => "Another Online Group")

    offline_groups = Group.offline_groups.all
    online_groups = Group.online_groups.all

    assert_equal 2, offline_groups.size
    assert_equal 1, offline_groups.select{|r| r.id == @offline_group.id}.size
    offline_groups.each do |g|
      assert g.group_offline?
    end

    assert_equal 3, online_groups.size
    assert_equal 1, online_groups.select{|r| r.id == another.id}.size
    assert_equal 1, online_groups.select{|r| r.id == @online_group.id}.size
    online_groups.each do |g|
      assert g.group_online?
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
  
  online_test "only offline indirect owned data cannot be destroyed" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_indirect_data.destroy
    end
    
    assert_nothing_raised do
      @online_indirect_data.destroy
    end
  end
  
  offline_test "offline groups unlocked and writable" do
    assert_equal false, @offline_group.locked_by_offroad?
    assert_nothing_raised do
      @offline_group.save!
    end
  end
  
  offline_test "offline group owned data unlocked and writable" do
    assert_equal false, @offline_group_data.locked_by_offroad?
    assert_nothing_raised do
      @offline_group_data.save!
    end
  end
  
  offline_test "offline indirectly owned data unlocked and writable" do
    assert_equal false, @offline_indirect_data.locked_by_offroad?
    assert_nothing_raised do
      @offline_indirect_data.save!
    end
  end
  
  offline_test "offline group owned data destroyable" do
    assert_nothing_raised do
      @offline_group_data.destroy
    end
  end
  
  offline_test "offline indirectly owned data destroyable" do
    assert_nothing_raised do
      @offline_indirect_data.destroy
    end
  end
  
  offline_test "cannot create another group" do
    assert_raise Offroad::DataError do
      Group.create(:name => "Another Offline Group?")
    end
  end
  
  offline_test "cannot destroy the group" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @offline_group.destroy
    end
  end
  
  offline_test "cannot change id of offline group data" do
    assert_raise Offroad::DataError do
      @offline_group.id += 1
      @offline_group.save!
    end
    
    assert_raise Offroad::DataError do
      @offline_group_data.id += 1
      @offline_group_data.save!
    end
    
    assert_raise Offroad::DataError do
      @offline_indirect_data.id += 1
      @offline_indirect_data.save!
    end
  end
  
  online_test "cannot change id of online group data" do
    assert_raise Offroad::DataError do
      @online_group.id += 1
      @online_group.save!
    end
    
    assert_raise Offroad::DataError do
      @online_group_data.id += 1
      @online_group_data.save!
    end
    
    assert_raise Offroad::DataError do
      @online_indirect_data.id += 1
      @online_indirect_data.save!
    end
  end
  
  offline_test "cannot set offline group to online" do
    assert_raise Offroad::DataError do
      @offline_group.group_offline = false
    end
  end
  
  online_test "group data cannot hold a foreign key to a record owned by another group" do
    # This is an online test because the concept of "another group" doesn't fly in offline mode
    @another_group = Group.create(:name => "Another Group")
    @another_group_data = GroupOwnedRecord.create(:description => "Another Piece of Data", :group => @another_group)
    @another_indirect_data = SubRecord.create(:description => "Yet Another Data Thingie", :group_owned_record => @another_group_data)
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in group base data" do
      @online_group.favorite = @another_group_data
      @online_group.save!
    end
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in group owned data" do
      @online_group_data.parent = @another_group_data
      @online_group_data.save!
    end
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in indirectly group owned data" do
      @online_indirect_data.buddy = @another_indirect_data
      @online_indirect_data.save!
    end
  end
  
  double_test "group data can hold a foreign key to data owned by the same group" do
    more_data = GroupOwnedRecord.create(:description => "More Data", :group => @editable_group, :parent => @editable_group_data)
    more_indirect_data = SubRecord.create(:description => "Yet More", :group_owned_record => more_data)
    assert_nothing_raised do
      @editable_group.favorite = more_data
      @editable_group.save!
      @editable_indirect_data.buddy = more_indirect_data
      @editable_indirect_data.save!
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

  double_test "group data can hold a foreign key to naive sync data" do
    naive_rec = NaiveSyncedRecord.create(:description => "Some naive synced data")
    assert_nothing_raised "No exception when putting global data key in group base data" do
      @editable_group.naive_synced_record = naive_rec
      @editable_group.save!
    end
    assert_nothing_raised "No exception when putting global data key in group owned data" do
      @editable_group_data.naive_synced_record = naive_rec
      @editable_group_data.save!
    end
  end
  
  double_test "group data cannot hold a foreign key to unmirrored data" do
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in group base data" do
      @editable_group.unmirrored_record = unmirrored_data
      @editable_group.save!
    end
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in group owned data" do
      @editable_group_data.unmirrored_record = unmirrored_data
      @editable_group_data.save!
    end
    assert_raise Offroad::DataError, "Expect exception when putting bad foreign key in indirectly owned data" do
      @editable_indirect_data.unmirrored_record = unmirrored_data
      @editable_indirect_data.save!
    end
  end
  
  online_test "last_known_status is not available for online groups" do
    assert_raise Offroad::DataError do
      status = @online_group.last_known_status
    end
  end
  
  double_test "last_known_status is available for offline groups" do
    status = @offline_group.last_known_status
    assert status
  end
  
  double_test "group data models return true to acts_as_offroadable?" do
    assert Group.acts_as_offroadable?, "Group reports mirrored offline"
    assert GroupOwnedRecord.acts_as_offroadable?, "GroupOwnedRecord reports mirrored offline"
  end
  
  online_test "cannot save :group_owned data with an invalid group id" do
    assert_raise Offroad::DataError do
      @offline_group_data.group_id = Group.maximum(:id)+1
      @offline_group_data.save(false) # Have to disable validations or it'll catch this error first
    end
  end
  
  online_test "cannot move :group_owned data from one group to another" do
    assert_raise Offroad::DataError do
      @offline_group_data.group = @online_group
      @offline_group_data.save!
    end
  end

  online_test "cannot move indirectly owned data from one group to another" do
    assert_raise Offroad::DataError do
      @offline_indirect_data.group_owned_record = @online_group_data
      @offline_indirect_data.save!
    end
  end

  online_test "can move indirectly owned data between parents in the same group" do
    another = GroupOwnedRecord.create(:description => "Another", :group => @online_group)
    assert another
    assert_nothing_raised do
      @online_indirect_data.group_owned_record = another
      @online_indirect_data.save!
    end
  end

  online_test "cannot create :group_owned data in an offline group" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      GroupOwnedRecord.create(:description => "Test", :group => @offline_group)
    end
  end

  online_test "cannot create indirectly group owned data in an offline group" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      SubRecord.create(:description => "Test", :group_owned_record => @offline_group_data)
    end
  end
end
