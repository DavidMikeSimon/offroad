require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle global models

class GlobalDataTest < Test::Unit::TestCase
  online_test "can create new global records" do
    assert_nothing_raised do
      GlobalRecord.create(:title => "Something or other")
    end
  end
  
  offline_test "cannot create new global records" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      GlobalRecord.create(:title => "Foo bar baz bork")
    end
  end
  
  double_test "global data models report being global data" do
    assert GlobalRecord.offroad_global_data?, "Global model should return true to offroad_global_data?"
    assert_equal false, GlobalRecord.offroad_group_data?, "Global model should return false to offroad_group_data?"
  end
  
  online_test "global data is writable and destroyable" do
    global_record = GlobalRecord.create(:title => "Something or other")
    assert !global_record.locked_by_offroad?
    assert_nothing_raised do
      global_record.title = "Something else"
      global_record.save!
      global_record.destroy
    end

    if HOBO_TEST_MODE
      guest = Guest.new
      global_record.permissive = true
      assert global_record.creatable_by?(guest)
      assert global_record.updatable_by?(guest)
      assert global_record.destroyable_by?(guest)
    end
  end
  
  offline_test "global data is not writable or destroyable" do
    global_record = GlobalRecord.new(:title => "Something or other")
    force_save_and_reload(global_record)
    assert global_record.locked_by_offroad?
    
    assert_raise ActiveRecord::ReadOnlyRecord, "expect exception on title change" do
      global_record.title = "Something else"
      global_record.save!
    end
    
    assert_raise ActiveRecord::ReadOnlyRecord, "expect exception on destroy" do
      global_record.destroy
    end

    if HOBO_TEST_MODE
      guest = Guest.new
      global_record.permissive = true
      assert !global_record.creatable_by?(guest)
      assert !global_record.updatable_by?(guest)
      assert !global_record.destroyable_by?(guest)
    end
  end
  
  online_test "cannot change id of global data" do
    global_record = GlobalRecord.create(:title => "Something or other")
    assert_raise Offroad::DataError do
      global_record.id += 1
      global_record.save!
    end
  end
  
  online_test "global data can hold a foreign key to other global data" do
    global_record = GlobalRecord.create(:title => "Something or other")
    another_global_record = GlobalRecord.create(:title => "Yet Another")
    
    assert_nothing_raised do
      global_record.friend = another_global_record
      global_record.save!
    end
  end
  
  online_test "global data cannot hold a foreign key to group data" do
    global_record = GlobalRecord.create(:title => "Something or other")
    assert_raise Offroad::DataError do
      global_record.some_group = @offline_group
      global_record.save!
    end
  end
  
  online_test "global data cannot hold a foreign key to unmirrored data" do
    global_record = GlobalRecord.create(:title => "Something or other")
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise Offroad::DataError do
      global_record.unmirrored_record = unmirrored_data
      global_record.save!
    end
  end
  
  double_test "global data models return true to acts_as_offroadable?" do
    assert GlobalRecord.acts_as_offroadable?
  end
end
