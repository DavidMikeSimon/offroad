require File.dirname(__FILE__) + '/../test_helper'

class AppStateTrackingTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  online_test "creating group base data causes creation of valid state data" do
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    assert_equal "Group", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal rec.id, rec_state.local_record_id, "SendableRecordState has correct record id"
    assert_equal 0, rec_state.remote_record_id, "SendableRecordState has no remote record id prior to mirror confirm"
    cur_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal cur_version, rec_state.mirror_version, "SendableRecordState has correct mirror version"
    
    group_state = OfflineMirror::GroupState::find_by_group(rec)
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 0, group_state.up_mirror_version, "As-yet un-mirrored group has an up mirror version of 0"
    assert_equal 0, group_state.down_mirror_version, "As-yet un-mirrored group has a down mirror version of 0"
  end
  
  common_test "creating group owned data causes creation of valid state data" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @editable_group)
    
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal rec.id, rec_state.local_record_id, "SendableRecordState has correct record id"
    assert_equal 0, rec_state.remote_record_id, "SendableRecordState has no remote record id prior to mirror confirm"
    cur_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal cur_version, rec_state.mirror_version, "SendableRecordState has correct mirror version"
  end
  
  online_test "creating global data causes creation of valid state data" do
    # The setup routine didn't create any GlobalRecords, so there shouldn't be any GlobalRecord record states yet
    assert_nothing_raised "No pre-existing SendableRecordStates for GlobalRecord" do
      OfflineMirror::SendableRecordState::find(:all, :include => [ :model_state]).each do |rec|
        raise "Already a GlobalRecord state entry!" if rec.model_state.app_model_name == "GlobalRecord"
      end
    end
    
    rec = GlobalRecord.create(:title => "Foo Bar")
    
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    assert rec_state, "SendableRecordState was created when record was created"
    assert_equal "GlobalRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal rec.id, rec_state.local_record_id, "SendableRecordState has correct record id"
    assert_equal 0, rec_state.remote_record_id, "SendableRecordState has no remote record id prior to mirror confirm"
    cur_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal cur_version, rec_state.mirror_version, "SendableRecordState has correct mirror version"
  end
  
  online_test "saving global data updates mirror version only on changed records" do
    rec = GlobalRecord.create(:title => "Foo Bar")
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Updating system's mirror version did not affect record version"
    
    rec.save!
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Save without changes did not affect record version"
    
    rec.title = "Narf Bork"
    rec.save!
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Save with changes updated record's version"
  end
  
  common_test "saving group base data updates mirror version only on changed records" do
    rec_state = OfflineMirror::SendableRecordState::find_by_record(@editable_group)
    
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Updating system's mirror version did not affect record version"
    
    @editable_group.save!
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Save without changes did not affect record version"
    
    @editable_group.name = "Narf Bork"
    @editable_group.save!
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Save with changes updated record's version"
  end
  
  common_test "saving group owned data updates mirror version only on changed records" do
    rec_state = OfflineMirror::SendableRecordState::find_by_record(@editable_group_data)
    
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Updating system's mirror version did not affect record version"
    
    @editable_group_data.save!
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Save without changes did not affect record version"
    
    @editable_group_data.description = "Narf Bork"
    @editable_group_data.save!
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Save with changes updated record's version"
  end
  
  common_test "can only find group state of models that are :group_base" do
  end
  
  common_test "can increment current mirror version" do
  end
  
end

run_test_class AppStateTrackingTest