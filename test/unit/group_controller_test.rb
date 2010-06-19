require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test for the functionality group controllers derive from GroupBaseController.
# It's small because testing the actual mirroring capability requires multiple environments.
# Look in the integration tests for that.

class GroupControllerTest < ActionController::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  def assert_single_cargo_section_named(cs, name)
    count = 0
    cs.each_cargo_section(name) do |data|
      count += 1
    end
    assert_equal 1, count
  end
  
  def assert_no_cargo_sections_named(cs, name)
    assert_nothing_raised do
      cs.each_cargo_section(name) do |data|
        raise "There shouldn't be any cargo sections with that name"
      end
    end
  end
  
  def assert_common_mirror_elements_appear_valid(cs, mode)
    assert_single_cargo_section_named cs, "mirror_info"
    
    mirror_info = cs.first_cargo_section("mirror_info")[0]
    assert_instance_of OfflineMirror::MirrorInfo, mirror_info
    migration_query = "SELECT version FROM schema_migrations ORDER BY version"
    migrations = Group.connection.select_all(migration_query).map{ |r| r["version"] }
    assert_equal migrations, mirror_info.schema_migrations.split(",").sort
    assert_equal mirror_info.app, OfflineMirror::app_name
    assert Time.now - mirror_info.created_at < 30
    assert mirror_info.app_mode.downcase.include?(mode.downcase)
    
    assert_single_cargo_section_named cs, "group_state"
    group_state = cs.first_cargo_section("group_state")[0]
    assert_instance_of OfflineMirror::GroupState, group_state
    assert_equal @offline_group.id, group_state.app_group_id
  end
  
  def assert_single_model_cargo_entry_matches(cs, record)
    data_name = "data_#{record.class.name}"
    assert_single_cargo_section_named cs, data_name
    data = cs.first_cargo_section(data_name)
    assert_equal 1, data.size
    assert_equal record.attributes, data[0].attributes
  end
  
  def assert_record_not_present(cs, record)
    data_name = "data_#{record.class.name}"
    assert_nothing_raised do
      cs.each_cargo_section(data_name) do |batch|
        batch.each do |cargo_record|
          raise "Undesired record found" if record.attributes == cargo_record.attributes
        end
      end
    end
  end
  
  # We know this will be an initial down mirror because the setup method sets the group's version attributes to 0
  online_test "can retrieve a valid initial down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database
    
    get :download_down_mirror, {"id" => @offline_group.id}
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("downloaded from the Test App online system")
    
    StringIO.open(content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_common_mirror_elements_appear_valid cs, "online"
      assert_single_model_cargo_entry_matches cs, global_record
      assert_single_model_cargo_entry_matches cs, @offline_group
      assert_single_model_cargo_entry_matches cs, @offline_group_data
    end
  end
  
  online_test "down mirror files do not include irrelevant records" do
    another_offline_group = Group.create(:name => "Another Group")
    another_offline_group.group_offline = true
    another_offline_group.reload
    another_group_data = GroupOwnedRecord.create(:description => "Another Data", :group => another_offline_group)
    another_group_data.reload
    
    get :download_down_mirror, {"id" => @offline_group.id}
    assert_response :success
    StringIO.open(@response.binary_content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_record_not_present cs, @another_offline_group
      assert_record_not_present cs, @another_group_data
      assert_single_model_cargo_entry_matches cs, @offline_group
      assert_single_model_cargo_entry_matches cs, @offline_group_data
    end
  end
  
  offline_test "cannot retrieve down mirror files in offline mode" do
    assert_raise OfflineMirror::PluginError do
      get :download_down_mirror, {"id" => @offline_group.id}
    end
  end
  
  offline_test "can retrieve a valid up mirror file for the offline group" do
    get :download_up_mirror, {"id" => @offline_group.id}
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("to the Test App online system")
    
    # This tests ViewHelper::link_to_online_app
    assert content.include?(">" + OfflineMirror::online_url + "</a>")
    assert content.include?("href=\"" + OfflineMirror::online_url + "\"")
    
    StringIO.open(content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_common_mirror_elements_appear_valid cs, "offline"
      assert_single_model_cargo_entry_matches cs, @offline_group
      assert_single_model_cargo_entry_matches cs, @offline_group_data
    end
  end
  
  offline_test "up mirror files do not include irrelevant records" do
    fake_offline_group = Group.new(:name => "Another Group")
    fake_offline_group.bypass_offline_mirror_readonly_checks
    fake_offline_group.save!
    fake_offline_group.reload
    
    fake_group_data = GroupOwnedRecord.new(:description => "Another Data", :group => fake_offline_group)
    fake_group_data.bypass_offline_mirror_readonly_checks
    fake_group_data.save!
    fake_group_data.reload
    
    fake_global_data = GlobalRecord.new(:title => "Fake Stuff")
    fake_global_data.bypass_offline_mirror_readonly_checks
    fake_global_data.save!
    fake_global_data.reload
    
    get :download_up_mirror, {"id" => @offline_group.id}
    assert_response :success
    StringIO.open(@response.binary_content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_record_not_present cs, fake_offline_group
      assert_record_not_present cs, fake_group_data
      assert_record_not_present cs, fake_global_data
      assert_single_model_cargo_entry_matches cs, @offline_group
      assert_single_model_cargo_entry_matches cs, @offline_group_data
    end
  end
  
  online_test "cannot retrieve up mirror files in online mode" do
    assert_raise OfflineMirror::PluginError do
      get :download_up_mirror, {"id" => @offline_group.id}
    end
  end
  
  online_test "cannot retrieve down mirror files for online groups" do
    assert_raise OfflineMirror::PluginError do
      get :download_down_mirror, {"id" => @online_group.id}
    end
  end
end

run_test_class GroupControllerTest