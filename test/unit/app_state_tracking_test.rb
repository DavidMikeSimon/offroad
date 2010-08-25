require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test for all the OfflineMirror internal models whose names end with "State"

class AppStateTrackingTest < Test::Unit::TestCase
  def assert_newly_created_record_matches_srs(rec, rec_srs)
    assert_equal rec.id, rec_srs.local_record_id, "SendableRecordState has correct record id"
    assert_equal OfflineMirror::SystemState::current_mirror_version, rec_srs.mirror_version
  end
  
  online_test "group state data is created when online group is made offline" do
    prior_group_state_count = OfflineMirror::GroupState::count
    rec = Group.create(:name => "Foo Bar")
    
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    rec.group_offline = true
    group_state = OfflineMirror::GroupState::find_by_app_group_id(rec.id)
    assert group_state
    assert_equal prior_group_state_count+1, OfflineMirror::GroupState::count, "GroupState was created on demand"
    assert_equal rec.id, group_state.app_group_id, "GroupState has correct app group id"
    assert_equal 1, group_state.confirmed_group_data_version, "Newly offline group has an group data version of 1"
    assert_equal OfflineMirror::SystemState::current_mirror_version, group_state.confirmed_global_data_version
  end
  
  online_test "can change offline state of groups" do
    assert @online_group.group_online?
    assert_equal false, @online_group.group_offline?
    @online_group.group_offline = true
    assert @online_group.group_offline?
    assert_equal false, @online_group.group_online?
    
    assert @offline_group.group_offline?
    assert_equal false, @offline_group.group_online?
    @offline_group.group_offline = false
    assert @offline_group.group_online?
    assert_equal false, @offline_group.group_offline?
  end
  
  online_test "state data is destroyed when offline group is made online" do
    rrs_scope = OfflineMirror::ReceivedRecordState.for_group(@offline_group)
    assert_not_equal 0, rrs_scope.count
    @offline_group.group_offline = false
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(@offline_group.id)
    assert_equal 0, rrs_scope.count
  end
  
  offline_test "creating group owned record causes creation of valid sendable record state" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @offline_group)
    
    rec_state = OfflineMirror::SendableRecordState.for_record(rec).first
    assert rec_state
    assert_equal "GroupOwnedRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_srs(rec, rec_state)
  end
  
  online_test "creating group owned record does not cause creation of sendable record state" do
    rec = GroupOwnedRecord.create(:description => "Foo Bar", :group => @online_group)
    assert_equal nil, OfflineMirror::SendableRecordState.for_record(rec).first
  end
  
  online_test "creating global record causes creation of valid sendable record state data" do
    assert_nothing_raised "No pre-existing SendableRecordStates for GlobalRecord" do
      OfflineMirror::SendableRecordState::find(:all, :include => [ :model_state]).each do |rec|
        raise "Already a GlobalRecord state entry!" if rec.model_state.app_model_name == "GlobalRecord"
      end
    end
    
    rec = GlobalRecord.create(:title => "Foo Bar")
    
    rec_state = OfflineMirror::SendableRecordState.for_record(rec).first
    assert rec_state, "SendableRecordState was created when record was created"
    assert_equal "GlobalRecord", rec_state.model_state.app_model_name, "ModelState has correct model name"
    assert_newly_created_record_matches_srs(rec, rec_state)
  end
  
  def assert_only_changing_attribute_causes_version_change(model, attribute, rec)
    rec_state = OfflineMirror::SendableRecordState.for_record(rec).first
    original_version = rec_state.mirror_version
    system_state = OfflineMirror::SystemState::instance_record
    system_state.current_mirror_version = original_version + 42
    system_state.save
    
    rec.save!
    rec_state.reload
    assert_equal original_version, rec_state.mirror_version, "Save without changes did not affect record version"
    
    rec.send((attribute.to_s + "=").to_sym, "Narf Bork")
    rec.save!
    rec_state.reload
    assert_equal original_version+42, rec_state.mirror_version, "Save with changes updated record's version"
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
    rec_state = OfflineMirror::SendableRecordState.for_record(rec).first
    assert_equal false, rec_state.deleted, "By default deleted flag is false"
    original_version = rec_state.mirror_version
    system_state = OfflineMirror::SystemState::instance_record
    system_state.current_mirror_version = original_version + 42
    system_state.save
    
    rec.destroy
    rec_state.reload
    assert_equal original_version+42, rec_state.mirror_version, "Deleting record updated version"
    assert_equal true, rec_state.deleted, "Deleting record deleted flag to true"
  end
  
  online_test "deleting global record updates mirror version" do
    rec = GlobalRecord.create(:title => "Foo Bar")
    assert_deleting_record_correctly_updated_record_state(rec)
  end
  
  offline_test "deleting group owned record updates mirror version" do
    assert_deleting_record_correctly_updated_record_state(@editable_group_data)
  end
  
  online_test "deleting offline group base record deletes corresponding group state" do
    assert_not_nil OfflineMirror::GroupState::find_by_app_group_id(@offline_group)
    @offline_group.destroy
    assert_nil OfflineMirror::GroupState::find_by_app_group_id(@offline_group)
  end
  
  online_test "can only create valid group state of saved group records that are :group_base" do
    assert_equal false, OfflineMirror::GroupState::for_group(@editable_group_data).new.valid?
    
    new_group = Group.new(:name => "Test")
    assert_equal false, OfflineMirror::GroupState::for_group(new_group).new.valid?
    new_group.save!
    assert OfflineMirror::GroupState::for_group(new_group).new.valid?
  end
  
  double_test "cannot create valid model state of unmirrored models" do
    model_state = OfflineMirror::ModelState::for_model(GlobalRecord).new
    assert model_state.valid?
    
    model_state = OfflineMirror::ModelState::for_model(UnmirroredRecord).new
    assert_equal false, model_state.valid?
  end
  
  double_test "cannot create valid model state of non-existent models" do
    model_state = OfflineMirror::ModelState::for_model(nil).new
    assert_equal false, model_state.valid?
    
    model_state = OfflineMirror::ModelState::new(:app_model_name => "this is not a constant name")
    assert_equal false, model_state.valid?
  end
  
  double_test "cannot create valid received record state of records of unmirrored models" do
    unmirrored_rec = UnmirroredRecord.create!(:content => "Test")
    assert_equal false, OfflineMirror::ReceivedRecordState.for_record(unmirrored_rec).new.valid?
  end
  
  double_test "cannot create valid sendable record state of records of unmirrored models" do
    unmirrored_rec = UnmirroredRecord.create!(:content => "Test")
    assert_equal false, OfflineMirror::SendableRecordState.for_record(unmirrored_rec).new.valid?
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
    rrs = OfflineMirror::ReceivedRecordState.for_record(group_data).new(:remote_record_id => 1)
    assert_equal false, rrs.valid?
  end
  
  online_test "cannot create valid sendable record state of unsaved records" do
    global_data = GlobalRecord.new(:title => "Test")
    srs = OfflineMirror::SendableRecordState.for_record(global_data).new
    assert_equal false, srs.valid?
  end
  
  double_test "can auto-generate system settings" do
    OfflineMirror::SystemState.instance_record.destroy
    
    assert_nothing_raised do
      OfflineMirror::SystemState.instance_record
    end
  end
  
  agnostic_test "can find associated model for all the foreign key columns in a given model" do
    foreign_keys = Group.offline_mirror_foreign_key_models
    assert foreign_keys.has_key?("favorite_id")
    assert foreign_keys.has_key?("global_record_id")
    assert foreign_keys.has_key?("unmirrored_record_id")
    assert_equal false, foreign_keys.has_key?("name")
    assert_equal GroupOwnedRecord, foreign_keys["favorite_id"]
    assert_equal GlobalRecord, foreign_keys["global_record_id"]
    assert_equal UnmirroredRecord, foreign_keys["unmirrored_record_id"]
  end
end
