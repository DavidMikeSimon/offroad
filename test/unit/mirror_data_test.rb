require File.dirname(__FILE__) + '/../test_helper'

class OfflineMirror::MirrorDataTest < ActiveSupport::TestCase
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
  
  online_test "can generate a valid down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database
    
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"])
    writer.write_downwards_data
    
    content.rewind
    cs = OfflineMirror::CargoStreamer.new(content, "r")
    assert_common_mirror_elements_appear_valid cs, "online"
    assert_single_model_cargo_entry_matches cs, global_record
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  online_test "down mirror files do not include irrelevant records" do
    another_offline_group = Group.create(:name => "Another Group")
    another_offline_group.group_offline = true
    another_offline_group.reload
    another_group_data = GroupOwnedRecord.create(:description => "Another Data", :group => another_offline_group)
    another_group_data.reload
    
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"])
    writer.write_downwards_data
    
    content.rewind
    cs = OfflineMirror::CargoStreamer.new(content, "r")
    assert_record_not_present cs, @another_offline_group
    assert_record_not_present cs, @another_group_data
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  offline_test "can generate a valid up mirror file for the offline group" do
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"])
    writer.write_upwards_data
    
    content.rewind
    cs = OfflineMirror::CargoStreamer.new(content, "r")
    assert_common_mirror_elements_appear_valid cs, "offline"
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
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
    
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"])
    writer.write_upwards_data
    
    content.rewind
    cs = OfflineMirror::CargoStreamer.new(content, "r")
    assert_record_not_present cs, fake_offline_group
    assert_record_not_present cs, fake_group_data
    assert_record_not_present cs, fake_global_data
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  offline_test "cannot upload an invalid down mirror file" do
    assert_raise OfflineMirror::DataError do
      OfflineMirror::MirrorData.new(@offline_group, "FOO BAR BLAH").load_downwards_data
    end
  end
  
  online_test "cannot upload an invalid up mirror file" do
    assert_raise OfflineMirror::DataError do
      OfflineMirror::MirrorData.new(@offline_group, "FOO BAR BLAH").load_upwards_data
    end
  end
  
  online_test "can insert and update group data using an up mirror file" do
    mirror_file = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      # TODO - Make some changes, use GBC backend to send to cs, then revert changes
      sio.string
    end
    
    assert @offline_group.name != "TEST 123"
    assert @offline_group_data.description != "TEST XYZ"
    assert_equal nil, GroupOwnedRecord.find_by_description("TEST ABC")
    
    # TODO - Apply the cargo file through the group controller
    
    assert @offline_group.name == "TEST 123"
    assert @offline_group_data.description == "TEST XYZ"
    assert GroupOwnedRecord.find_by_description("TEST ABC")
  end
  
  online_test "can delete group data using an up mirror file" do
    # TODO Implement
    flunk
  end
  
  offline_test "can insert and update global records using a down mirror file" do
    # TODO Implement
    flunk
  end
  
  offline_test "can delete global records using a down mirror file" do
    # TODO Implement
    flunk
  end
  
  offline_test "can insert group records using an initial down mirror file" do
    # TODO Implement
    flunk
  end
  
  online_test "cannot pass a down mirror file to load_upwards_data" do
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"], "offline")
    writer.write_downwards_data
    
    content.rewind
    reader = OfflineMirror::MirrorData.new(@offline_group, content)
    assert_raise OfflineMirror::DataError do
      reader.load_upwards_data
    end
  end
  
  offline_test "cannot pass an up mirror file to load_downwards_data" do
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(@offline_group, [content, "w"], "offline")
    writer.write_upwards_data
    
    content.rewind
    reader = OfflineMirror::MirrorData.new(@offline_group, content)
    assert_raise OfflineMirror::DataError do
      reader.load_downwards_data
    end
  end
end

run_test_class OfflineMirror::MirrorDataTest