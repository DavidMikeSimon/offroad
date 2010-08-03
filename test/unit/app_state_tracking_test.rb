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
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    rec_state = find_record_state_from_record(rec)
    assert_equal "Group", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal Group.object_id, rec_state.model_state.app_model.object_id
    assert_newly_created_record_matches_state(rec, rec_state)
    
    group_state = OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 0, group_state.up_mirror_version, "As-yet un-mirrored group has an up mirror version of 0"
    assert_equal 0, group_state.down_mirror_version, "As-yet un-mirrored group has a down mirror version of 0"
  end
  
  double_test "creating group owned record causes creation of valid state data" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @editable_group)
    
    rec_state = find_record_state_from_record(rec)
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal GroupOwnedRecords.object_id, rec_state.model_state.app_model.object_id
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
    
    rec_state = find_record_state_from_record(rec)
    assert rec_state, "SendableRecordState was created when record was created"
    assert_equal "GlobalRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_equal GlobalRecord.object_id, rec_state.model_state.app_model.object_id
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
  
  double_test "saving group base record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(Group, :name, @editable_group)
  end
  
  double_test "saving group owned record updates mirror version only on changed records" do
    assert_only_changing_attribute_causes_version_change(GroupOwnedRecord, :description, @editable_group_data)
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
  
  online_test "deleting group base record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group)
  end
  
  double_test "deleting group owned record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group_data)
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
  
  def assert_record_state_method_only_works_on_saved_mirrored_records(name)
    unmirrored_rec = UnmirroredRecord.create(:content => "Test")
    assert_raise OfflineMirror::ModelError do
      OfflineMirror::SendableRecordState.send(name, unmirrored_rec)
    end
    
    group_rec = GroupOwnedRecord.new(:description => "Test", :group => @editable_group)
    assert_raise OfflineMirror::DataError do
      OfflineMirror::SendableRecordState.send(name, group_rec)
    end
    
    group_rec.save!
    assert_nothing_raised do
      OfflineMirror::SendableRecordState.send(name, group_rec)
    end
  end
  
  double_test "can only find_or_initialize record state of records whose models act_as_mirrored_offline" do
    assert_record_state_method_only_works_on_saved_mirrored_records :find_or_initialize_by_record
  end
  
  double_test "can note create/update on saved records whose models act_as_mirrored_offline" do
    assert_record_state_method_only_works_on_saved_mirrored_records :note_record_created_or_updated
  end
  
  double_test "can only note deletion on saved records whose models act_as_mirrored_offline" do
    assert_record_state_method_only_works_on_saved_mirrored_records :note_record_destroyed
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
