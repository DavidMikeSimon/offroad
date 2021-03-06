require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TestFrameworkTest < Test::Unit::TestCase
  cross_test "online and offline databases are independent" do
    in_offline_app do
      assert_equal 0, UnmirroredRecord.count
      UnmirroredRecord.create(:content => "Testing")
    end
    
    in_online_app do
      assert_equal 0, UnmirroredRecord.count
    end
    
    in_offline_app do
      assert UnmirroredRecord.find_by_content("Testing")
    end
  end
  
  cross_test "online-specific and offline-specific instance variables are independent" do
    in_offline_app do
      @offline_group.name = "Foo"
      @offline_group.save!
      assert_equal "Foo", @offline_group.name
    end
    
    in_online_app do
      assert_not_equal "Foo", @offline_group.name
    end
    
    in_offline_app do
      assert_equal "Foo", @offline_group.name
    end
  end
  
  cross_test "instance variables lose unsaved data on mode switch" do
    in_offline_app do
      @offline_group.name = "Foo"
      assert_equal "Foo", @offline_group.name
      # Didn't save @offline_group
    end
    
    in_offline_app do
      assert_not_equal "Foo", @offline_group.name
    end
  end

  offline_test "callback detection switch on GroupOwnedRecord works on save" do
    GroupOwnedRecord.reset_callback_called
    assert !GroupOwnedRecord.callback_called
    @offline_group_data.description = "Testing"
    @offline_group_data.save!
    assert GroupOwnedRecord.callback_called
  end

  offline_test "callback detection switch on GroupOwnedRecord works on create" do
    GroupOwnedRecord.reset_callback_called
    assert !GroupOwnedRecord.callback_called
    GroupOwnedRecord.create!(:description => "Another new one", :group => @offline_group)
    assert GroupOwnedRecord.callback_called
  end

  offline_test "callback detection switch on GroupOwnedRecord works on destroy" do
    GroupOwnedRecord.reset_callback_called
    assert !GroupOwnedRecord.callback_called
    @offline_group_data.destroy
    assert GroupOwnedRecord.callback_called
  end

  if HOBO_TEST_MODE
    class CommonHoboTestModel < ActiveRecord::Base
      include CommonHobo
      set_table_name "broken_records" # Not important since we won't be saving anything
    end
    agnostic_test "simple unmirrored data hobo permissions work as expected" do
      g = Guest.new
      c = CommonHoboTestModel.new
      assert !c.creatable_by?(g)
      assert !c.updatable_by?(g)
      assert !c.destroyable_by?(g)
      c.permissive = true
      assert c.creatable_by?(g)
      assert c.updatable_by?(g)
      assert c.destroyable_by?(g)
    end
  end
end
