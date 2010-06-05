require File.dirname(__FILE__) + '/../test_helper'

class GlobalDataTest < ActiveSupport::TestCase
  def setup
    if OfflineMirror::app_offline?
      opts = {
        :offline_group_id => 1,
        :current_mirror_version => 1
      }
      OfflineMirror::SystemState::create(opts) or raise "Unable to create offline-mode testing SystemState"
      @offline_group = Group.new(:name => "An Offline Group")
      @offline_group.bypass_offline_mirror_readonly_checks
      @offline_group.save!
      @offline_group_data = GroupOwnedRecord.create(:description => "Some Offline Data", :group => @offline_group)
      raise "Test id mismatch" unless @offline_group.id == OfflineMirror::SystemState::current_mirror_version
    end
    
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
  
  online_test "global data is savable and destroyable" do
    assert_nothing_raised do
      @global_record.title = "Something else"
      @global_record.save!
      @global_record.destroy
    end
  end
  
  offline_test "global data is not savable or destroyable" do
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
end

run_test_class GlobalDataTest
