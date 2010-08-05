require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test for all the OfflineMirror internal models whose names end with "State"

class AppStateTrackingTest < Test::Unit::TestCase
  def find_record_state_from_record(rec)
    model_state = OfflineMirror::ModelState::find_by_app_model_name(rec.class.name)
    return OfflineMirror::SendableRecordState::find_by_model_state_id_and_local_record_id(model_state.id, rec.id)
  end
  
  agnostic_test "can increment current mirror version" do
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
    # TODO This should only work when the group is offline; online, no state data should be created
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    # TODO Check record state
    
    group_state = OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 0, group_state.up_mirror_version, "As-yet un-mirrored group has an up mirror version of 0"
    assert_equal 0, group_state.down_mirror_version, "As-yet un-mirrored group has a down mirror version of 0"
  end
  
  online_test "state data is created when online group is made offline" do
    # TODO Implement
  end
  
  online_test "state data is destroyed when offline group is made online" do
    # TODO Implement
  end
  
  offline_test "creating group owned record causes creation of valid state data" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @offline_group)
    
    rec_state = find_record_state_from_record(rec)
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
    
    group_state = OfflineMirror::GroupState::find_by_app_group_id(rec.group_id)
    assert_equal group_state.id, rec_state.group_state_id
  end
  
  online_test "creating group owned record does not cause creation of record state" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @online_group)
    assert_equal nil, find_record_state_from_record(rec)
  end
  
  online_test "creating global record causes creation of valid state data" do
    # The setup routine didn't create any GlobalRecords, so there shouldn't be any GlobalRecord record states yet
    assert_nothing_raised "No pre-existing SendableRecordStates for GlobalRecord" do
      OfflineMirror::SendableRecordState::find(:all, :include => [ :model_state]).each do |rec|
        raise "Already a GlobalRecord state entry!" if rec.model_state.app_model_name == "GlobalRecord"
      end
    end
    
    rec = GlobalRecord.create(:title => "Foo Bar")
    
    rec_state = find_record_state_from_record(rec)
    assert rec_state, "SendableRecordState was created when record was created"
    assert_equal "GlobalRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
  end
  
  def assert_only_changing_attribute_causes_version_change(model, attribute, rec)
    rec_state = find_record_state_from_record(rec)
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
  
  offline_test "saving group base record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(Group, :name, @offline_group)
  end
  
  offline_test "saving group owned record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(GroupOwnedRecord, :description, @offline_group_data)
  end
  
  def assert_deleting_record_correctly_updated_record_state(rec)
    rec_state = find_record_state_from_record(rec)
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
  
  offline_test "deleting group owned record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group_data)
  end
  
  online_test "deleting online group base record deletes corresponding group state" do
    assert_not_nil OfflineMirror::GroupState::find_by_app_group_id(@online_group)
    @online_group.destroy
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(@online_group)
  end
  
  online_test "deleting offline group base record deletes corresponding group state" do
    assert_not_nil OfflineMirror::GroupState::find_by_app_group_id(@offline_group)
    @offline_group.destroy
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(@offline_group)
  end
  
  online_test "can only find_or_create group state of saved group records that are :group_base" do
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::GroupState::find_or_create_by_group(@editable_group_data)
    end
    
    new_group = Group.new(:name => "Test")
    assert_raise OfflineMirror::DataError do
      OfflineMirror::GroupState::find_or_create_by_group(new_group)
    end
    new_group.save!
    assert_nothing_raised do
      OfflineMirror::GroupState::find_or_create_by_group(new_group)
    end
  end
  
  double_test "can only find_or_create model state of models that act_as_mirrored_offline" do
    assert_nothing_raised do
      OfflineMirror::ModelState::find_or_create_by_model(GlobalRecord)
    end
    
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::ModelState::find_or_create_by_model(UnmirroredRecord)
    end
  end
  
  def assert_method_only_works_on_saved_mirrored_records(method_name, test_class)
    unmirrored_rec = UnmirroredRecord.create(:content => "Test")
    assert_raise OfflineMirror::ModelError do
      test_class.send(method_name, unmirrored_rec)
    end
    
    group_rec = GroupOwnedRecord.new(:description => "Test", :group => @editable_group)
    assert_raise OfflineMirror::DataError do
      test_class.send(method_name, group_rec)
    end
    
    group_rec.save!
    assert_nothing_raised do
      test_class.send(method_name, group_rec)
    end
  end
  
  double_test "can only create receivable record state of records whose models act_as_mirrored_offline" do
    # TODO Implement
  end
  
  online_test "can only create receivable record state of offline group data records" do
    # TODO Implement
  end
  
  online_test "can only create sendable record state of global data records" do
    # TODO Implement
  end
  
  offline_test "can only create receivable record state of global data records" do
    # TODO Implement
  end
  
  online_test "can only create sendable record state of group data records" do
    # TODO Implement
  end
  
  double_test "can only find_or_initialize sendable record state of records whose models act_as_mirrored_offline" do
    assert_method_only_works_on_saved_mirrored_records :find_or_initialize_by_record, SendableRecordState
  end
  
  double_test "can note create/update on saved records whose models act_as_mirrored_offline" do
    assert_method_only_works_on_saved_mirrored_records :note_record_created_or_updated, SendableRecordState
  end
  
  double_test "can only note deletion on saved records whose models act_as_mirrored_offline" do
    assert_method_only_works_on_saved_mirrored_records :note_record_destroyed, SendableRecordState
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
