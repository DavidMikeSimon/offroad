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
  
  cross_test "can pass data to MirrorData read methods as CargoStreamer, String, or IO" do
    mirror_data = ""
    in_online_app do
      GlobalRecord.create(:title => "Foo Bar")
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
    end
    
    sources = [
      OfflineMirror::CargoStreamer.new(mirror_data, "r"),
      StringIO.new(mirror_data, "r"),
      mirror_data
    ]
    sources.each do |source|
      in_offline_app(true) do
        assert_equal 0, GlobalRecord.count
        OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(source)
        assert GlobalRecord.find_by_title("Foo Bar")
      end
    end
  end
  
  offline_test "can have MirrorData write methods send to CargoStreamer, IO, or return value" do
    cargo_streamer_sio = StringIO.new
    cargo_streamer = OfflineMirror::CargoStreamer.new(cargo_streamer_sio, "w")
    direct_sio = StringIO.new
    
    writer = OfflineMirror::MirrorData.new(@offline_group)
    writer.write_upwards_data(cargo_streamer)
    writer.write_upwards_data(direct_sio)
    str = writer.write_upwards_data
    
    cargo_streamer_sio.rewind
    direct_sio.rewind
    result_a = OfflineMirror::CargoStreamer.new(cargo_streamer_sio, "r").cargo_section_names
    result_b = OfflineMirror::CargoStreamer.new(direct_sio, "r").cargo_section_names
    result_c = OfflineMirror::CargoStreamer.new(StringIO.new(str), "r").cargo_section_names
    
    assert result_a.size > 0
    assert result_a == result_b
    assert result_b == result_c
  end
  
  online_test "can generate a valid initial down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database
    
    str = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_common_mirror_elements_appear_valid cs, "online"
    assert_single_model_cargo_entry_matches cs, global_record
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  online_test "can generate a valid down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database
    
    str = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_common_mirror_elements_appear_valid cs, "online"
    assert_single_model_cargo_entry_matches cs, global_record
    assert_record_not_present cs, @offline_group
    assert_record_not_present cs, @offline_group_data
  end
  
  online_test "initial down mirror files do not include irrelevant records" do    
    another_offline_group = Group.create(:name => "Another Group")
    another_offline_group.group_offline = true
    another_group_data = GroupOwnedRecord.new(:description => "Another Data", :group => another_offline_group)
    force_save_and_reload(another_group_data)
    [another_offline_group, another_group_data].each { |r| r.reload }
    
    str = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_record_not_present cs, another_offline_group
    assert_record_not_present cs, another_group_data
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  online_test "down mirror files do not include irrelevant records" do    
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database
    another_offline_group = Group.create(:name => "Another Group")
    another_offline_group.group_offline = true
    another_group_data = GroupOwnedRecord.new(:description => "Another Data", :group => another_offline_group)
    force_save_and_reload(another_group_data)
    [another_offline_group, another_group_data].each { |r| r.reload }
    
    str = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_record_not_present cs, another_offline_group
    assert_record_not_present cs, another_group_data
    assert_record_not_present cs, @offline_group
    assert_record_not_present cs, @offline_group_data
    assert_single_model_cargo_entry_matches cs, global_record
  end
  
  offline_test "can generate a valid up mirror file for the offline group" do
    str = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_common_mirror_elements_appear_valid cs, "offline"
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end
  
  offline_test "up mirror files do not include irrelevant records" do
    fake_global_data = GlobalRecord.new(:title => "Fake Stuff")
    force_save_and_reload(fake_global_data)
    
    str = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    assert_record_not_present cs, fake_global_data
  end
  
  offline_test "cannot upload an invalid down mirror file" do
    assert_raise OfflineMirror::DataError do
      OfflineMirror::MirrorData.new(@offline_group).load_downwards_data("FOO BAR BLAH")
    end
  end
  
  online_test "cannot upload an invalid up mirror file" do
    assert_raise OfflineMirror::DataError do
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data("FOO BAR BLAH")
    end
  end
  
  offline_test "cannot use load_upwards_data in offline mode" do
    assert_raise OfflineMirror::PluginError do
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data("FOO BAR BLAH")
    end
  end
  
  online_test "cannot use load_downwards_data in online mode" do
    assert_raise OfflineMirror::PluginError do
      OfflineMirror::MirrorData.new(@offline_group).load_downwards_data("FOO BAR BLAH")
    end
  end
   
  cross_test "can insert and update group data using an up mirror file" do
    mirror_data = ""
    
    in_offline_app do
      @offline_group.name = "TEST 123"
      @offline_group_data.description = "TEST XYZ"
      another_group_data = GroupOwnedRecord.new(:description => "TEST ABC", :group => @offline_group)
      force_save_and_reload(@offline_group, @offline_group_data, another_group_data)
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    end
    
    in_online_app do
      prior_rrs_count = OfflineMirror::ReceivedRecordState.count
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal prior_rrs_count+1, OfflineMirror::ReceivedRecordState.count 
      assert_equal @offline_group.id, Group.find_by_name("TEST 123").id
      assert GroupOwnedRecord.find_by_description("TEST ABC")
      assert_equal @offline_group_data.id, GroupOwnedRecord.find_by_description("TEST XYZ").id
    end
  end
  
  cross_test "can delete group data using an up mirror file" do
    mirror_data = ""
    
    in_offline_app do
      @offline_group_data.destroy
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    end
    
    in_online_app do
      prior_rrs_count = OfflineMirror::ReceivedRecordState.count
      assert_equal 1, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal prior_rrs_count-1, OfflineMirror::ReceivedRecordState.count
      assert_equal 0, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
    end
  end
  
  cross_test "can insert and update and delete global records using a down mirror file" do
    mirror_data = ""
    
    in_online_app do
      GlobalRecord.create(:title => "ABC")
      GlobalRecord.create(:title => "123")
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
    end
    
    offline_number_rec_id = nil
    in_offline_app do
      rrs_scope = OfflineMirror::ReceivedRecordState.for_model(GlobalRecord)
      assert_equal 0, rrs_scope.count
      assert_equal 0, GlobalRecord.count
      OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      assert_equal 2, rrs_scope.count
      assert_equal 2, GlobalRecord.count
      assert_not_nil GlobalRecord.find_by_title("ABC")
      assert_not_nil GlobalRecord.find_by_title("123")
      offline_number_rec_id = GlobalRecord.find_by_title("123")
    end
    
    in_online_app do
      number_rec = GlobalRecord.find_by_title("123")
      number_rec.title = "789"
      number_rec.save!
      
      letter_rec = GlobalRecord.find_by_title("ABC")
      letter_rec.destroy
      
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
    end
    
    in_offline_app do
      rrs_scope = OfflineMirror::ReceivedRecordState.for_model(GlobalRecord)
      OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      assert_equal 1, rrs_scope.count
      assert_equal 1, GlobalRecord.count
      assert_nil GlobalRecord.find_by_title("ABC")
      assert_nil GlobalRecord.find_by_title("123")
      assert_not_nil GlobalRecord.find_by_title("789")
      assert_equal offline_number_rec_id, GlobalRecord.find_by_title("789")
    end
  end
  
  cross_test "can insert group records using an initial down mirror file" do
    mirror_data = ""
    in_online_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end
    
    in_offline_app(false, true) do
      assert_equal 0, Group.count
      assert_equal 0, GroupOwnedRecord.count
      assert_equal 0, OfflineMirror::SendableRecordState.for_model(Group).count
      assert_equal 0, OfflineMirror::SendableRecordState.for_model(GroupOwnedRecord).count
      OfflineMirror::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      assert_equal 1, Group.count
      assert_equal 1, GroupOwnedRecord.count
      assert_equal 1, OfflineMirror::SendableRecordState.for_model(Group).count
      assert_equal 1, OfflineMirror::SendableRecordState.for_model(GroupOwnedRecord).count
    end
  end
  
  cross_test "if no SystemState is present an initial down mirror file is required" do
    mirror_data = ""
    in_online_app { mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data }
    
    in_offline_app(false, true) do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(nil).load_downwards_data(mirror_data)
      end
    end
  end
  
  cross_test "importing an initial down mirror file deletes all currently existing records" do
    mirror_data = ""
    in_online_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end
    
    in_offline_app do
      @offline_group.update_attribute(:name, "Old")
      group_data = GroupOwnedRecord.new(:description => "Old", :group => @offline_group)
      global_data = GlobalRecord.new(:title => "Old")
      force_save_and_reload(group_data, global_data)
      UnmirroredRecord.create(:content => "Old Old Old")
      
      OfflineMirror::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      
      assert_equal nil, Group.find_by_name("Old")
      assert_equal nil, GroupOwnedRecord.find_by_description("Old")
      assert_equal 1, Group.count
      assert_equal 1, GroupOwnedRecord.count
      assert_equal 0, GlobalRecord.count
      assert_equal 0, UnmirroredRecord.count
    end
  end
  
  cross_test "importing an initial down mirror file resets autoincrement counters" do
    mirror_data = ""
    in_online_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end
    
    in_offline_app do
      global_rec_a = GlobalRecord.new(:title => "A")
      global_rec_b = GlobalRecord.new(:title => "B")
      global_rec_c = GlobalRecord.new(:title => "C")
      force_save_and_reload(global_rec_a, global_rec_b, global_rec_c)
      
      OfflineMirror::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      
      global_rec = GlobalRecord.new(:title => "Test")
      force_save_and_reload(global_rec)
      assert_equal 1, global_rec.id
    end
  end
  
#   cross_test "cannot affect group records in offline app using a non-initial down mirror file" do
#     # TODO Implement
#   end
  
  cross_test "cannot upload an initial down mirror file unless passed :initial_mode => true to MirrorData.new" do
    mirror_data = ""
    in_online_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end
    
    in_offline_app do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end
  
  cross_test "cannot upload a non-initial down mirror file after passing :initial_mode => true to MirrorData.new" do
    mirror_data = ""
    in_online_app { mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data }
    
    in_offline_app do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).load_downwards_data(mirror_data)
      end
    end
  end
  
  cross_test "cannot pass a down mirror file to load_upwards_data" do
    mirror_data = ""
    
    in_online_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_downwards_data
      
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end
    
    in_offline_app do
      assert_nothing_raised do
        OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end
  
  offline_test "cannot pass an up mirror file to load_downwards_data" do
    mirror_data = ""
    
    in_offline_app do
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
      
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
    
    in_online_app do
      assert_nothing_raised do
        OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end
  end
  
#   cross_test "cannot use an up mirror file to create or update or delete records not owned by the given group" do
#     # TODO Implement
#   end
#   
#   cross_test "cannot use an up mirror file to delete the group record itself" do
#     # TODO Implement
#   end
#   
#   cross_test "cannot use a down mirror file to delete the group record itself" do
#     # TODO Implement
#   end
  
  cross_test "transformed ids are handled properly when loading an up mirror file" do
    in_online_app do
      another_online_record = GroupOwnedRecord.create(:description => "Yet Another", :group => @online_group)
    end
    
    mirror_data = ""
    offline_id_of_new_rec = nil
    in_offline_app do
      another_offline_rec = GroupOwnedRecord.create(:description => "One More", :group => @offline_group)
      offline_id_of_new_rec = another_offline_rec.id
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    end
    
    in_online_app do
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      rec = GroupOwnedRecord.find_by_description("One More")
      assert rec
      assert_equal offline_id_of_new_rec, OfflineMirror::ReceivedRecordState.for_record(rec).first.remote_record_id
    end
  end
  
  cross_test "transformed ids are handled properly when loading an initial down mirror file" do
    mirror_data = ""
    online_id_of_offline_rec = nil
    in_online_app do
      another_online_record = GroupOwnedRecord.create(:description => "Yet Another", :group => @online_group)
      another_offline_rec = GroupOwnedRecord.new(:description => "One More", :group => @offline_group)
      force_save_and_reload(another_offline_rec)
      online_id_of_offline_rec = another_offline_rec.id
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end
    
    in_offline_app do
      OfflineMirror::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      rec = GroupOwnedRecord.find_by_description("One More")
      assert_equal online_id_of_offline_rec, rec.id
      rec.description = "Back To The Future"
      rec.save!
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    end
    
    in_online_app do
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal nil, GroupOwnedRecord.find_by_description("One More")
      assert_equal "Back To The Future", GroupOwnedRecord.find(online_id_of_offline_rec).description
    end
  end
    
  online_test "initial down mirror files do not include deletion entries" do
    global_record = GlobalRecord.create(:title => "Something")
    global_record.destroy
    
    str = OfflineMirror::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = OfflineMirror::CargoStreamer.new(str, "r")
    deletion_cargo_name = OfflineMirror::MirrorData.send(:deletion_cargo_name_for_model, GlobalRecord)
    assert_equal false, cs.has_cargo_named?(deletion_cargo_name)
  end
  
  cross_test "cannot import up mirror files with invalid records" do
    mirror_data = ""
    in_offline_app do
      group_rec = GroupOwnedRecord.new(:description => "Invalid record", :group => @offline_group, :should_be_even => 3)
      group_rec.save_without_validation
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :skip_write_validation => true).write_upwards_data
    end
    
    in_online_app do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end
  end
  
  cross_test "cannot import down mirror files with invalid records" do
    mirror_data = ""
    in_online_app do
      global_rec = GlobalRecord.new(:title => "Invalid record", :should_be_odd => 2)
      global_rec.save_without_validation
      mirror_data = OfflineMirror::MirrorData.new(@offline_group, :skip_write_validation => true).write_downwards_data
    end
    
    in_offline_app do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end
  
  cross_test "cannot import initial down mirror files with invalid records" do
    mirror_data = ""
    in_online_app do
      group_rec = GroupOwnedRecord.new(:description => "Invalid record", :group => @online_group, :should_be_even => 3)
      group_rec.save_without_validation
      @online_group.group_offline = true
      writer = OfflineMirror::MirrorData.new(@online_group, :skip_write_validation => true, :initial_mode => true)
      mirror_data = writer.write_downwards_data
    end
    
    in_offline_app(false, true) do
      assert_raise OfflineMirror::DataError do
        OfflineMirror::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      end
    end
  end
  
  cross_test "transformed ids in foreign key columns are handled correctly" do
    in_online_app do
      # Perturb the autoincrement a bit
      GroupOwnedRecord.create(:description => "Alice", :group => @online_group)
      GroupOwnedRecord.create(:description => "Bob", :group => @online_group)
    end
    
    mirror_data = ""
    in_offline_app do
      parent = GroupOwnedRecord.create(:description => "Celia", :group => @offline_group)
      child_a = GroupOwnedRecord.create(:description => "Daniel", :parent => parent, :group => @offline_group)
      child_b = GroupOwnedRecord.create(:description => "Eric", :parent => parent, :group => @offline_group)
      grandchild = GroupOwnedRecord.create(:description => "Fran", :parent => child_b, :group => @offline_group)
      @offline_group.favorite = grandchild
      @offline_group.save!
      @offline_group_data.parent = grandchild
      @offline_group_data.save!
      mirror_data = OfflineMirror::MirrorData.new(@offline_group).write_upwards_data
    end
    
    in_online_app do
      OfflineMirror::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      
      @offline_group.reload
      @offline_group_data.reload
      parent = GroupOwnedRecord.find_by_description("Celia")
      child_a = GroupOwnedRecord.find_by_description("Daniel")
      child_b = GroupOwnedRecord.find_by_description("Eric")
      grandchild = GroupOwnedRecord.find_by_description("Fran")
      
      assert_equal parent, child_a.parent
      assert_equal parent, child_b.parent
      assert_equal child_b, grandchild.parent
      assert_equal grandchild, child_b.children.first
      assert_equal grandchild, @offline_group.favorite
      assert_equal @offline_group_data, grandchild.children.first
      assert_equal grandchild, @offline_group_data.parent
    end
  end
  
#   cross_test "mirror files do not include unchanged records" do
#     # TODO Implement
#   end
#   
#   cross_test "mirror files do not include deletion requests for records known to be deleted on remote system" do
#     # TODO Implement
#   end
#   
#   cross_test "deleting received records also deletes received record state" do
#     # TODO Implement
#   end
#   
#   cross_test "records from other groups are not included in initial down mirror files" do
#     # TODO Implement
#   end
end
