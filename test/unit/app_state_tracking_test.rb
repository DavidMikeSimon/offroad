require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test for all the OfflineMirror internal models whose names end with "State"

class AppStateTrackingTest < Test::Unit::TestCase
  def find_srs_from_record(rec)
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
    cur_version = OfflineMirror::SystemState::current_mirror_version
    assert_equal cur_version, rec_state.mirror_version, "SendableRecordState has correct mirror version"
  end
  
  online_test "cannot create valid GroupState for online group" do
    group_state = OfflineMirror::GroupState.find_or_create_by_group(@online_group)
    assert_equal false, group_state.valid?
  end
  
  online_test "group state data is created when online group is made offline" do
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    group.offline_group = true
    group_state = OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    assert group_state
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 0, group_state.up_mirror_version, "As-yet un-mirrored group has an up mirror version of 0"
    assert_equal 0, group_state.down_mirror_version, "As-yet un-mirrored group has a down mirror version of 0"
  end
  
  online_test "state data is destroyed when offline group is made online" do
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@offline_group)
    assert_not_equal 0, rrs_scope.count
    @offline_group.group_offline = false
    assert_equal 0, rrs_scope.count
  end
  
  offline_test "creating group owned record causes creation of valid sendable record state" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @offline_group)
    
    rec_state = find_srs_from_record(rec)
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
  end
  
  online_test "creating group owned record does not cause creation of sendable record state" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @online_group)
    assert_equal nil, find_srs_from_record(rec)
  end
  
  online_test "creating global record causes creation of valid sendable record state data" do
    # The setup routine didn't create any GlobalRecords, so there shouldn't be any GlobalRecord record states yet
    assert_nothing_raised "No pre-existing SendableRecordStates for GlobalRecord" do
      OfflineMirror::SendableRecordState::find(:all, :include => [ :model_state]).each do |rec|
        raise "Already a GlobalRecord state entry!" if rec.model_state.app_model_name == "GlobalRecord"
      end
    end
    
    rec = GlobalRecord.create(:title => "Foo Bar")
    
    rec_state = find_srs_from_record(rec)
    assert rec_state, "SendableRecordState was created when record was created"
    assert_equal "GlobalRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_state(rec, rec_state)
  end
  
  def assert_only_changing_attribute_causes_version_change(model, attribute, rec)
    rec_state = find_srs_from_record(rec)
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
    rec_state = find_srs_from_record(rec)
    assert_equal false, rec_state.deleted, "By default deleted flag is false"
    original_version = OfflineMirror::SystemState::current_mirror_version
    OfflineMirror::SystemState::increment_mirror_version
    
    rec.destroy
    rec_state.reload
    assert_equal original_version+1, rec_state.mirror_version, "Deleting record updated version"
    assert_equal true, rec_state.deleted, "Deleting record deleted flag to true"
    # TODO If a srs is of the current version, just destroy the srs as well on record destruction
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
  
  online_test "can only create valid group state of saved group records that are :group_base" do
    assert_equal false, OfflineMirror::GroupState::find_or_create_by_group(@editable_group_data).valid?
    
    new_group = Group.new(:name => "Test")
    assert_equal false, OfflineMirror::GroupState::find_or_create_by_group(new_group).valid?
    new_group.save!
    assert OfflineMirror::GroupState::find_or_create_by_group(new_group).valid?
  end
  
  double_test "cannot create valid model state of unmirrored models" do
    model_state = OfflineMirror::ModelState::find_or_create_by_model(GlobalRecord)
    assert model_state.valid?
    
    model_state = OfflineMirror::ModelState::find_or_create_by_model(UnmirroredRecord)
    assert_equal false, model_state.valid?
  end
  
  double_test "cannot create valid model state of non-existent models" do
    model_state = OfflineMirror::ModelState::find_or_create_by_model(nil)
    assert_equal false, model_state.valid?
  end
  
  double_test "cannot create valid received record state of records of unmirrored models" do
    unmirrored_rec = UnmirroredRecord.new(:content => "Test")
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@offline_group).for_model(UnmirroredRecord)
    rrs = rrs_scope.new(:local_record_id => unmirrored_rec.id, :remote_record_id => 1)
    assert_equal false, rrs.valid?
  end
  
  online_test "cannot create valid received record state of online group data records" do
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@online_group).for_model(GroupOwnedRecord)
    rrs = rrs_scope.new(:local_record_id => @online_group_data.id, :remote_record_id => 1)
    assert_equal false, rrs.valid?
  end
  
  online_test "cannot create valid sendable record state of group data records" do
    srs_scope = OfflineMirror::SendableRecordState.for_model(GroupOwnedRecord)
    srs = srs_scope.new(:local_record_id => @offline_group_data.id)
    assert_equal false, srs.valid?
  end
  
  online_test "cannot create valid received record state of global data records" do
    global_rec = GlobalRecord.create(:title => "Testing")
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@online_group).for_model(GlobalRecord)
    rrs = rrs_scope.new(:local_record_id => global_rec.id, :remote_record_id => 1)
    assert_equal false, rrs.valid?
  end
  
  offline_test "cannot create valid received record state of group data records" do
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@offline_group).for_model(GroupOwnedRecord)
    rrs = rrs_scope.new(:local_record_id => @offline_group_data.id)
    assert_equal false, rrs.valid?
  end
  
  offline_test "cannot create valid sendable record state of global data records" do
    global_rec = GlobalRecord.new(:title => "Testing")
    force_save_and_reload(global_rec)
    srs_scope = OfflineMirror::SendableRecordState.for_model(GlobalRecord)
    srs = srs_scope.new(:local_record_id => global_rec.id)
    assert_equal false, srs.valid?
  end
  
  online_test "cannot create valid received record state of unsaved records" do
    group_data = GroupOwnedRecord.new(:description => "Test", :group => @offline_group)
    rrs = OfflineMirror::ReceivedRecordState.create_by_record_and_remote_record_id(group_data, 1)
    assert_equal false, rrs.valid?
  end
  
  online_test "cannot create valid sendable record state of unsaved records" do
    global_data = GlobalRecord.new(:title => "Test")
    force_save_and_reload(global_data)
    srs = OfflineMirror::SendableRecordState.find_or_create_by_record(global_data)
    assert_equal false, srs.valid?
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
