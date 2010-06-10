require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test for the functionality group controllers derive from GroupBaseController.
# It's small because testing the actual mirroring capability requires multiple environments.
# Look in the integration tests for that.

class GroupControllerTest < ActionController::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  def assert_single_cargo_sections_named(cs, names)
    names.each do |name|
      count = 0
      cs.each_cargo_section(name) do |data|
        count += 1
      end
      assert_equal 1, count
    end
  end
  
  def assert_common_mirror_elements_appear_valid(cs)
    assert_single_cargo_sections_named cs, ["file_info", "group_state", "schema_migrations"]
    assert_equal false, cs.first_cargo_section("file_info").empty?
    assert_equal @offline_group.id, cs.first_cargo_section("group_state")["app_group_id"]
    assert_equal false, cs.first_cargo_section("schema_migrations").empty?
  end
  
  def assert_single_model_cargo_entry_matches(cs, record)
    data_name = "data_#{record.class.name}"
    assert_single_cargo_sections_named cs, [data_name]
    data = cs.first_cargo_section(data_name)
    assert_equal 1, data.size
    assert_equal record.simplified_attributes, data[0]
  end
  
  # We know this will be an initial down mirror because the setup method sets the group's version attributes to 0
  online_test "can retrieve a valid initial down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    
    get :download_down_mirror, {"id" => @offline_group.id}
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    
    StringIO.open(@response.binary_content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_common_mirror_elements_appear_valid cs
      assert_single_model_cargo_entry_matches cs, global_record
      assert_single_model_cargo_entry_matches cs, @offline_group
      assert_single_model_cargo_entry_matches cs, @offline_group_data
    end
  end
end

run_test_class GroupControllerTest