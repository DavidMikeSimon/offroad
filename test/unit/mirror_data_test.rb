require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MirrorDataTest < Test::Unit::TestCase
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
    
    mirror_info = cs.first_cargo_element("mirror_info")
    assert_instance_of OfflineMirror::MirrorInfo, mirror_info
    migration_query = "SELECT version FROM schema_migrations ORDER BY version"
    migrations = Group.connection.select_all(migration_query).map{ |r| r["version"] }
    assert_equal migrations, mirror_info.schema_migrations.split(",").sort
    assert_equal mirror_info.app, OfflineMirror::app_name
    assert Time.now - mirror_info.created_at < 30
    assert mirror_info.app_mode.downcase.include?(mode.downcase)
    
    assert_single_cargo_section_named cs, "group_state"
    group_state = cs.first_cargo_element("group_state")
    assert_instance_of OfflineMirror::GroupState, group_state
    assert_equal @offline_group.id, group_state.app_group_id
  end
  
  def assert_single_model_cargo_entry_matches(cs, record)
    data_name = "data_#{record.class.name}"
    assert_single_cargo_section_named cs, data_name
    assert_equal record.attributes, cs.first_cargo_element(data_name).attributes
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
  
  cross_test "can only pass data to MirrorData instances as CargoStreamer, String, or IO" do
    mirror_data = ""
    in_online_app do
      StringIO.open do |sio|
        GlobalRecord.create(:title => "Foo Bar")
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
    end
    
    sources = [
      OfflineMirror::CargoStreamer.new(StringIO.new(mirror_data), "r"),
      mirror_data,
      [StringIO.new(mirror_data), "r"],
      [mirror_data, "r"]
    ]
    sources.each do |source|
      in_offline_app(true) do
        assert_equal 0, GlobalRecord.count
        reader = OfflineMirror::MirrorData.new(@offline_group, source)
        reader.load_downwards_data
        assert GlobalRecord.find_by_title("Foo Bar")
      end
    end
    
    in_offline_app(true) do
      assert_raise OfflineMirror::PluginError do
        OfflineMirror::MirrorData.new(@offline_group, 123)
      end
      assert_raise OfflineMirror::PluginError do
        OfflineMirror::MirrorData.new(@offline_group, nil)
      end
    end
  end
  
  double_test "cannot pass weird mode to MirrorData::new" do
    assert_raise OfflineMirror::PluginError do
      OfflineMirror::MirrorData.new(@offline_group, "", "foobar")
    end
    assert_nothing_raised do
      OfflineMirror::MirrorData.new(@offline_group, "", OfflineMirror::app_online? ? "online" : "offline")
    end
  end
  
  double_test "MirrorData picks the current app mode if none is supplied" do
    m = OfflineMirror::MirrorData.new(@offline_group, "")
    m.mode == OfflineMirror::app_online? ? "online" : "offline"
  end
  
  double_test "MirrorData can be given the opposite of the current app mode" do
    reverse_mode = OfflineMirror::app_offline? ? "online" : "offline"
    m = OfflineMirror::MirrorData.new(@offline_group, "", reverse_mode)
    assert_equal reverse_mode, m.mode
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
    another_group_data = GroupOwnedRecord.new(:description => "Another Data", :group => another_offline_group)
    force_save_and_reload(another_group_data)
    [another_offline_group, another_group_data].each { |r| r.reload }
    
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
    fake_group_data = GroupOwnedRecord.new(:description => "Another Data", :group => fake_offline_group)
    fake_global_data = GlobalRecord.new(:title => "Fake Stuff")
    force_save_and_reload(fake_offline_group, fake_group_data, fake_global_data)
    
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
   
  cross_test "can insert and update group data using an up mirror file" do
    mirror_data = ""
    
    in_offline_app do
      @offline_group.name = "TEST 123"
      @offline_group_data.description = "TEST XYZ"
      another_group_data = GroupOwnedRecord.new(:description => "TEST ABC", :group => @offline_group)
      force_save_and_reload(@offline_group, @offline_group_data, another_group_data)
      
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_upwards_data
        mirror_data = sio.string
      end
    end
    
    in_online_app do
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      reader.load_upwards_data
      
      assert_equal @offline_group.id, Group.find_by_name("TEST 123").id
      assert GroupOwnedRecord.find_by_description("TEST ABC")
      assert_equal @offline_group_data.id, GroupOwnedRecord.find_by_description("TEST XYZ").id
    end
  end
  
  cross_test "can delete group data using an up mirror file" do
    mirror_data = ""
    
    in_offline_app do
      @offline_group_data.destroy
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_upwards_data
        mirror_data = sio.string
      end
    end
    
    in_online_app do
      assert_equal 1, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      reader.load_upwards_data
      assert_equal 0, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
    end
  end
  
  cross_test "can insert and update global records using a down mirror file" do
    mirror_data = ""
    
    in_offline_app do
      global_data_a = GlobalRecord.new(:title => "XYZ")
      force_save_and_reload(global_data_a)
      assert_equal 1, global_data_a.id
      force_consider_as_mirrored(global_data_a)
    end
    
    in_online_app do
      global_data_a = GlobalRecord.new(:title => "ABC")
      global_data_b = GlobalRecord.new(:title => "123")
      force_save_and_reload(global_data_a, global_data_b)
      assert_equal 1, global_data_a.id
      force_consider_as_mirrored(global_data_a, global_data_b)
      
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
    end
    
    in_offline_app do
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      reader.load_downwards_data
      assert_equal 1, GlobalRecord.find_by_title("ABC").id
      assert GlobalRecord.find_by_title("123")
      assert_equal nil, GlobalRecord.find_by_title("XYZ")
    end
  end
  
  cross_test "can delete global records using a down mirror file" do
    in_offline_app do
      global_data_1 = GlobalRecord.new(:title => "Test 1")
      global_data_2 = GlobalRecord.new(:title => "Test 2")
      force_save_and_reload(global_data_1, global_data_2)
      force_consider_as_mirrored(global_data_1, global_data_2)
    end
    
    mirror_data = ""
    in_online_app do
      global_data_1 = GlobalRecord.new(:title => "Test 1")
      global_data_2 = GlobalRecord.new(:title => "Test 2")
      force_save_and_reload(global_data_1, global_data_2)
      force_consider_as_mirrored(global_data_1, global_data_2)
      global_data_1.destroy
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
    end
    
    in_offline_app do
      assert_equal 2, GlobalRecord.count
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      reader.load_downwards_data
      assert_equal 1, GlobalRecord.count
      assert_equal nil, GlobalRecord.find_by_title("Test 1")
      assert GlobalRecord.find_by_title("Test 2")
    end
  end
  
  cross_test "can insert group records using an initial down mirror file" do
    mirror_data = ""
    in_online_app do
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
    end
    
    in_offline_app(false, true) do
      assert_equal 0, Group.count
      assert_equal 0, GroupOwnedRecord.count
      reader = OfflineMirror::MirrorData.new(nil, mirror_data)
      reader.load_downwards_data
      assert_equal 1, Group.count
      assert_equal 1, GroupOwnedRecord.count
    end
  end
  
  cross_test "if no SystemState is present an initial down mirror file is required" do
    # TODO Imlpement
  end
  
  cross_test "cannot affect group records using a non-initial down mirror file" do
    # TODO Implement
  end
  
  cross_test "cannot pass a down mirror file to load_upwards_data" do
    mirror_data = ""
    
    in_online_app do
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
      
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      assert_raise OfflineMirror::DataError do
        reader.load_upwards_data
      end
    end
    
    in_offline_app do
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      assert_nothing_raised do
        reader.load_downwards_data
      end
    end
  end
  
  offline_test "cannot pass an up mirror file to load_downwards_data" do
    mirror_data = ""
    
    in_offline_app do
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_upwards_data
        mirror_data = sio.string
      end
      
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      assert_raise OfflineMirror::DataError do
        reader.load_downwards_data
      end
    end
    
    in_online_app do
      reader = OfflineMirror::MirrorData.new(@offline_group, mirror_data)
      assert_nothing_raised do
        reader.load_upwards_data
      end
    end
  end
  
  double_test "cannot pass in a cargo file containing extraneous sections" do
    # TODO Implement
  end
  
  cross_test "cannot use an up mirror file to create or update or delete records not owned by the given group" do
    # TODO Implement
  end
  
  cross_test "transformed ids are handled properly when loading an up mirror file" do
    # TODO Implement
  end
  
  cross_test "transformed ids are handled properly when loading an initial down mirror file" do
    mirror_data = ""
    online_id_of_offline_rec = nil
    in_online_app do
      another_online_record = GroupOwnedRecord.create(:description => "Yet Another", :group => @online_group)
      another_offline_rec = GroupOwnedRecord.new(:description => "One More", :group => @offline_group)
      force_save_and_reload(another_offline_rec)
      online_id_of_offline_rec = another_offline_rec.id
      StringIO.open do |sio|
        writer = OfflineMirror::MirrorData.new(@offline_group, [sio, "w"])
        writer.write_downwards_data
        mirror_data = sio.string
      end
    end
    
    in_offline_app do
      reader = OfflineMirror::MirrorData.new(nil, mirror_data)
      reader.load_downwards_data
      another_offline_rec = GroupOwnedRecord.find_by_description("One More")
      srs = OfflineMirror::SendableRecordState::find_or_initialize_by_record(another_offline_rec)
      assert_equal online_id_of_offline_rec, srs.remote_record_id
    end
  end
  
  cross_test "transformed ids in foreign key columns are handled correctly" do
    # TODO Implement
  end
  
  cross_test "mirror files do not include unchanged records" do
    # TODO Implement
  end
  
  cross_test "mirror files do not include deletion requests for records known to be deleted on remote system" do
    # TODO Implement
  end
end
