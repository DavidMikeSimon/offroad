require File.dirname(__FILE__) + '/../test_helper'

class AppStateTrackingTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  common_test "can increment current mirror version" do
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    new_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal original_version+1, new_version
  end
  
  def assert_newly_created_record_matches_state(rec, rec_state)
    assert_equal rec.id, rec_state.local_record_id, "SendableRecordState has correct record id"
    assert_equal 0, rec_state.remote_record_id, "SendableRecordState has no remote record id prior to mirror confirm"
    cur_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal cur_version, rec_state.mirror_version, "SendableRecordState has correct mirror version"
  end
  
  online_test "creating group base record causes creation of valid state data" do
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    assert_equal "Group", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
    
    group_state = OfflineMirror::GroupState::find_by_group(rec)
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 0, group_state.up_mirror_version, "As-yet un-mirrored group has an up mirror version of 0"
    assert_equal 0, group_state.down_mirror_version, "As-yet un-mirrored group has a down mirror version of 0"
  end
  
  common_test "creating group owned record causes creation of valid state data" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @editable_group)
    
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
  end
  
  online_test "creating global record causes creation of valid state data" do
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
    assert_newly_created_record_matches_state(rec, rec_state)
  end
  
  def assert_only_changing_attribute_causes_version_change(model, attribute, rec)
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec.save!
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Save without changes did not affect record version"
    
    rec.send((attribute.to_s + "=").to_sym, "Narf Bork")
    rec.save!
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Save with changes updated record's version"
  end
  
  online_test "saving global record updates mirror version only on changed records" do
    rec = GlobalRecord.create(:title => "Foo Bar")
    assert_only_changing_attribute_causes_version_change(GlobalRecord, :title, rec)
  end
  
  common_test "saving group base record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(Group, :name, @editable_group)
  end
  
  common_test "saving group owned record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(GroupOwnedRecord, :description, @editable_group_data)
  end
  
  def assert_deleting_record_correctly_updated_record_state(rec)
    rec_state = OfflineMirror::SendableRecordState::find_by_record(rec)
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec.destroy
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Deleting record updated version"
    assert_equal 0, rec_state.local_record_id, "Deleting record set local id to 0"
    # TODO If a record was never part of any mirror file, just destroy the record state as well on its destruction
    # This implies that we need a test here that involves creating a fake mirror file
  end
  
  online_test "deleting global record updates mirror version" do
    rec = GlobalRecord.create(:title => "Foo Bar")
    assert_deleting_record_correctly_updated_record_state(rec)
  end
  
  online_test "deleting group base record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group)
  end
  
  common_test "deleting group owned record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group_data)
  end
  
  common_test "can only find group state of models that are :group_base" do
    assert_nothing_raised do
      OfflineMirror::GroupState::find_by_group(@editable_group)
    end
    
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::GroupState::find_by_group(@editable_group_data)
    end
  end
  
  common_test "can only find model state of models that act_as_mirrored_offline" do
    assert_nothing_raised do
      OfflineMirror::ModelState::find_by_model(Group)
    end
    
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::ModelState::find_by_model(UnmirroredRecord)
    end
  end
  
  common_test "can only find record state of records whose models act_as_mirrored_offline" do
    assert_nothing_raised do
      OfflineMirror::SendableRecordState::find_by_record(@editable_group)
    end
    
    unmirrored_rec = UnmirroredRecord.new(:content => "Test")
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::SendableRecordState::find_by_record(unmirrored_rec)
    end
  end
  
  offline_test "cannot auto-generate system settings" do
    OfflineMirror::SystemState.instance_record.destroy
    
    assert_raise OfflineMirror::DataError do
      OfflineMirror::SystemState.instance_record
    end
  end
  
  online_test "can auto-generate system settings" do
    OfflineMirror::SystemState.instance_record.destroy
    
    assert_nothing_raised do
      OfflineMirror::SystemState.instance_record
    end
  end
  
end

run_test_class AppStateTrackingTest