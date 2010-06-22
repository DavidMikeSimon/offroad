require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to handle global models

class GlobalDataTest < Test::Unit::TestCase
  def setup
    super
    
    @global_record = GlobalRecord.new(:title => "Something or other")
    force_save_and_reload(@global_record)
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
    assert_raise ActiveRecord::ReadOnlyRecord, "expect exception on title change" do
      @global_record.title = "Something else"
      @global_record.save!
    end
    
    assert_raise ActiveRecord::ReadOnlyRecord, "expect exception on destroy" do
      @global_record.destroy
    end
  end
  
  online_test "cannot change id of global data" do
    assert_raise OfflineMirror::DataError do
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
    assert_raise OfflineMirror::DataError do
      @global_record.some_group = @offline_group
      @global_record.save!
    end
  end
  
  online_test "global data cannot hold a foreign key to unmirrored data" do
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise OfflineMirror::DataError do
      @global_record.unmirrored_record = unmirrored_data
      @global_record.save!
    end
  end
  
  common_test "global data models return true to acts_as_mirrored_offline?" do
    assert GlobalRecord.acts_as_mirrored_offline?
  end
end