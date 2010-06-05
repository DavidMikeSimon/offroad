require File.dirname(__FILE__) + '/../test_helper'

class GlobalDataTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
    
    @global_record = GlobalRecord.new(:title => "Something or other")
    # If we didn't do this, offline test wouldn't be able to create the record
    @global_record.bypass_offline_mirror_readonly_checks
    @global_record.save!
  end
  
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
  
  common_test "global data models report being global data" do
    assert GlobalRecord.offline_mirror_global_data?, "Global model should return true to offline_mirror_global_data?"
    assert_equal false, GlobalRecord.offline_mirror_group_data?, "Global model should return false to offline_mirror_group_data?"
  end
  
  online_test "global data is writable and destroyable" do
    assert_nothing_raised do
      @global_record.title = "Something else"
      @global_record.save!
      @global_record.destroy
    end
  end
  
  offline_test "global data is not writable or destroyable" do
    assert_raise ActiveRecord::ReadOnlyRecord do
      @global_record.title = "Something else"
      @global_record.save!
    end
    
    assert_raise ActiveRecord::ReadOnlyRecord do
      @global_record.destroy
    end
  end
  
  common_test "cannot change id of global data" do
    assert_raise ActiveRecord::ReadOnlyRecord, RuntimeError do
      @global_record.id += 1
      @global_record.save!
    end
  end
  
  online_test "global data can hold a foreign key to other global data" do
    another_global_record = GlobalRecord.create(:title => "Yet Another")
    
    assert_nothing_raised do
      @global_record.friend = another_global_record
      @global_record.save!
    end
  end
  
  online_test "global data cannot hold a foreign key to group data" do
    assert_raise RuntimeError do
      @global_record.some_group = @offline_group
      @global_record.save!
    end
  end
  
  online_test "global data cannot hold a foreign key to unmirrored data" do
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise RuntimeError do
      @global_record.unmirrored_record = unmirrored_data
      @global_record.save!
    end
  end
end

run_test_class GlobalDataTest
