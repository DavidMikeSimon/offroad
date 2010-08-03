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
end
