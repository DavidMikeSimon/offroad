require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MirrorDataTest < Test::Unit::TestCase
  online_test "cannot create MirrorData instance for online group" do
    assert_raise Offroad::DataError do
      Offroad::MirrorData.new(@online_group)
    end
  end
  
  def all_records_from_section_named(cs, name)
    recs = []
    cs.each_cargo_section(name) do |batch|
      recs += batch
    end
    return recs
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

    mirror_info = cs.first_cargo_element("mirror_info")
    assert_instance_of Offroad::MirrorInfo, mirror_info
    migration_query = "SELECT version FROM schema_migrations ORDER BY version"
    migrations = Group.connection.select_all(migration_query).map{ |r| r["version"] }
    assert_equal migrations, mirror_info.schema_migrations.split(",").sort
    assert_equal mirror_info.app, Offroad::app_name
    assert Time.now - mirror_info.created_at < 30
    assert mirror_info.app_mode.downcase.include?(mode.downcase)

    assert_single_cargo_section_named cs, "group_state"
    group_state = cs.first_cargo_element("group_state")
    assert_instance_of Offroad::GroupState, group_state
    assert_equal @offline_group.id, group_state.app_group_id
  end

  def assert_single_model_cargo_entry_matches(cs, record)
    record.reload
    data_name = Offroad::MirrorData.send(:data_cargo_name_for_model, record.class)
    assert_single_cargo_section_named cs, data_name
    assert_equal record.attributes, cs.first_cargo_element(data_name).attributes
  end

  def assert_record_not_present(cs, record)
    record.reload
    data_name = Offroad::MirrorData.send(:data_cargo_name_for_model, record.class)
    assert_nothing_raised do
      cs.each_cargo_section(data_name) do |batch|
        batch.each do |cargo_record|
          raise "Undesired record found" if record.attributes == cargo_record.attributes
        end
      end
    end
  end

  cross_test "can pass data to MirrorData read methods as CargoStreamer, String, or IO" do
    mirror_data = nil
    in_online_app do
      GlobalRecord.create(:title => "Foo Bar")
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    sources = [
      Offroad::CargoStreamer.new(mirror_data, "r"),
      StringIO.new(mirror_data, "r"),
      mirror_data
    ]
    sources.each do |source|
      in_offline_app(true) do
        assert_equal 0, GlobalRecord.count
        Offroad::MirrorData.new(@offline_group).load_downwards_data(source)
        assert GlobalRecord.find_by_title("Foo Bar")
      end
    end
  end

  offline_test "can have MirrorData write methods send to CargoStreamer, IO, or return value" do
    cargo_streamer_sio = StringIO.new
    cargo_streamer = Offroad::CargoStreamer.new(cargo_streamer_sio, "w")
    direct_sio = StringIO.new

    writer = Offroad::MirrorData.new(@offline_group)
    writer.write_upwards_data(cargo_streamer)
    writer.write_upwards_data(direct_sio)
    str = writer.write_upwards_data

    cargo_streamer_sio.rewind
    direct_sio.rewind
    result_a = Offroad::CargoStreamer.new(cargo_streamer_sio, "r").cargo_section_names
    result_b = Offroad::CargoStreamer.new(direct_sio, "r").cargo_section_names
    result_c = Offroad::CargoStreamer.new(StringIO.new(str), "r").cargo_section_names

    assert result_a.size > 0
    assert result_a == result_b
    assert result_b == result_c
  end

  online_test "can generate a valid initial down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database

    str = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    assert_common_mirror_elements_appear_valid cs, "online"
    assert_single_model_cargo_entry_matches cs, global_record
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end

  online_test "can convert online group to an offline group and generate valid initial down mirror file" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database

    @online_group.group_offline = true
    str = Offroad::MirrorData.new(@online_group, :initial_mode => true).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    assert_single_model_cargo_entry_matches cs, global_record
    assert_single_model_cargo_entry_matches cs, @online_group
    assert_single_model_cargo_entry_matches cs, @online_group_data
  end

  online_test "can generate a valid down mirror file for the offline group" do
    global_record = GlobalRecord.create(:title => "Foo Bar")
    global_record.reload # To clear the high time precision that is lost in the database

    str = Offroad::MirrorData.new(@offline_group).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
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

    str = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
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

    str = Offroad::MirrorData.new(@offline_group).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    assert_record_not_present cs, another_offline_group
    assert_record_not_present cs, another_group_data
    assert_record_not_present cs, @offline_group
    assert_record_not_present cs, @offline_group_data
    assert_single_model_cargo_entry_matches cs, global_record
  end

  offline_test "can generate a valid up mirror file for the offline group" do
    @offline_group.name = "Changed"
    @offline_group.save!
    @offline_group.reload
    @offline_group_data.some_integer = 5551212
    @offline_group_data.save!
    @offline_group_data.reload
    str = Offroad::MirrorData.new(@offline_group).write_upwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    assert_common_mirror_elements_appear_valid cs, "offline"
    assert_single_model_cargo_entry_matches cs, @offline_group
    assert_single_model_cargo_entry_matches cs, @offline_group_data
  end

  offline_test "up mirror files do not include irrelevant records" do
    fake_global_data = GlobalRecord.new(:title => "Fake Stuff")
    force_save_and_reload(fake_global_data)

    str = Offroad::MirrorData.new(@offline_group).write_upwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    assert_record_not_present cs, fake_global_data
  end

  offline_test "cannot upload an invalid down mirror file" do
    assert_raise Offroad::DataError do
      Offroad::MirrorData.new(@offline_group).load_downwards_data("FOO BAR BLAH")
    end
  end

  online_test "cannot upload an invalid up mirror file" do
    assert_raise Offroad::DataError do
      Offroad::MirrorData.new(@offline_group).load_upwards_data("FOO BAR BLAH")
    end
  end

  offline_test "cannot use load_upwards_data in offline mode" do
    assert_raise Offroad::PluginError do
      Offroad::MirrorData.new(@offline_group).load_upwards_data("FOO BAR BLAH")
    end
  end

  online_test "cannot use load_downwards_data in online mode" do
    assert_raise Offroad::PluginError do
      Offroad::MirrorData.new(@offline_group).load_downwards_data("FOO BAR BLAH")
    end
  end

  cross_test "can insert and update group data using an up mirror file" do
    mirror_data = nil

    in_offline_app do
      @offline_group.name = "TEST 123"
      @offline_group_data.description = "TEST XYZ"
      another_group_data = GroupOwnedRecord.new(:description => "TEST ABC", :group => @offline_group)
      force_save_and_reload(@offline_group, @offline_group_data, another_group_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      prior_rrs_count = Offroad::ReceivedRecordState.count
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal prior_rrs_count+1, Offroad::ReceivedRecordState.count 
      assert_equal @offline_group.id, Group.find_by_name("TEST 123").id
      assert GroupOwnedRecord.find_by_description("TEST ABC")
      assert_equal @offline_group_data.id, GroupOwnedRecord.find_by_description("TEST XYZ").id
    end
  end

  cross_test "can delete group data using an up mirror file" do
    mirror_data = nil

    in_offline_app do
      @offline_group_data.destroy
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      prior_rrs_count = Offroad::ReceivedRecordState.count
      assert_equal 1, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal prior_rrs_count-1, Offroad::ReceivedRecordState.count
      assert_equal 0, GroupOwnedRecord.count(:conditions => { :group_id => @offline_group.id })
    end
  end

  cross_test "can insert and update and delete global records using a down mirror file" do
    mirror_data = nil

    in_online_app do
      GlobalRecord.create(:title => "ABC")
      GlobalRecord.create(:title => "123")
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    offline_number_rec_id = nil
    in_offline_app do
      rrs_scope = Offroad::ReceivedRecordState.for_model(GlobalRecord)
      assert_equal 0, rrs_scope.count
      assert_equal 0, GlobalRecord.count
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
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

      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      rrs_scope = Offroad::ReceivedRecordState.for_model(GlobalRecord)
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      assert_equal 1, rrs_scope.count
      assert_equal 1, GlobalRecord.count
      assert_nil GlobalRecord.find_by_title("ABC")
      assert_nil GlobalRecord.find_by_title("123")
      assert_not_nil GlobalRecord.find_by_title("789")
      assert_equal offline_number_rec_id, GlobalRecord.find_by_title("789")
    end
  end

  cross_test "can insert group records using an initial down mirror file" do
    mirror_data = nil
    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app(false, true) do
      assert_equal 0, Group.count
      assert_equal 0, GroupOwnedRecord.count
      assert_equal 0, Offroad::SendableRecordState.for_model(Group).count
      assert_equal 0, Offroad::SendableRecordState.for_model(GroupOwnedRecord).count
      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      assert_equal 1, Group.count
      assert_equal 1, GroupOwnedRecord.count
      assert_equal 1, Offroad::SendableRecordState.for_model(Group).count
      assert_equal 1, Offroad::SendableRecordState.for_model(GroupOwnedRecord).count
    end
  end

  cross_test "can insert global records using an initial down mirror file" do
    mirror_data = nil
    in_online_app do
      GlobalRecord.create(:title => "Something")
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app(false, true) do
      assert_equal 0, GlobalRecord.count
      assert_equal 0, Offroad::SendableRecordState.for_model(GlobalRecord).count
      assert_equal 0, Offroad::ReceivedRecordState.for_model(GlobalRecord).count
      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      assert_equal 1, GlobalRecord.count
      assert_not_nil GlobalRecord.find_by_title("Something")
      assert_equal 0, Offroad::SendableRecordState.for_model(GlobalRecord).count
      assert_equal 1, Offroad::ReceivedRecordState.for_model(GlobalRecord).count
    end
  end

  cross_test "cannot load regular down mirror file in empty offline app" do
    mirror_data = nil
    in_online_app { mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data }

    in_offline_app(false, true) do
      assert_raise Offroad::PluginError do
        Offroad::MirrorData.new(nil).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "importing an initial down mirror file deletes all currently existing records" do
    mirror_data = nil
    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app do
      @offline_group.update_attribute(:name, "Old")
      group_data = GroupOwnedRecord.new(:description => "Old", :group => @offline_group)
      global_data = GlobalRecord.new(:title => "Old")
      force_save_and_reload(group_data, global_data)
      UnmirroredRecord.create(:content => "Old Old Old")

      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)

      assert_equal nil, Group.find_by_name("Old")
      assert_equal nil, GroupOwnedRecord.find_by_description("Old")
      assert_equal 1, Group.count
      assert_equal 1, GroupOwnedRecord.count
      assert_equal 0, GlobalRecord.count
      assert_equal 0, UnmirroredRecord.count
    end
  end

  cross_test "importing an initial down mirror file resets autoincrement counters" do
    mirror_data = nil
    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app do
      global_rec_a = GlobalRecord.new(:title => "A")
      global_rec_b = GlobalRecord.new(:title => "B")
      global_rec_c = GlobalRecord.new(:title => "C")
      force_save_and_reload(global_rec_a, global_rec_b, global_rec_c)

      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)

      global_rec = GlobalRecord.new(:title => "Test")
      force_save_and_reload(global_rec)
      assert_equal 1, global_rec.id
    end
  end

  cross_test "cannot upload an initial down mirror file unless passed :initial_mode => true to MirrorData.new" do
    mirror_data = nil
    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot upload a non-initial down mirror file after passing :initial_mode => true to MirrorData.new" do
    mirror_data = nil
    in_online_app { mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data }

    in_offline_app do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group, :initial_mode => true).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot upload a non-initial down mirror file to a blank offline instance" do
    mirror_data = nil
    in_online_app { mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data }

    in_offline_app(false, true) do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot pass a down mirror file to load_upwards_data" do
    mirror_data = nil

    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data

      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end

    in_offline_app do
      assert_nothing_raised do
        Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot pass an up mirror file to load_downwards_data" do
    mirror_data = nil

    in_offline_app do
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data

      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end

    in_online_app do
      assert_nothing_raised do
        Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end
  end

  cross_test "transformed ids are handled properly when loading an up mirror file" do
    in_online_app do
      another_online_record = GroupOwnedRecord.create(:description => "Yet Another", :group => @online_group)
    end

    mirror_data = nil
    offline_id_of_new_rec = nil
    in_offline_app do
      another_offline_rec = GroupOwnedRecord.create(:description => "One More", :group => @offline_group)
      offline_id_of_new_rec = another_offline_rec.id
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      rec = GroupOwnedRecord.find_by_description("One More")
      assert rec
      assert_equal offline_id_of_new_rec, Offroad::ReceivedRecordState.for_record(rec).first.remote_record_id
    end
  end

  cross_test "transformed ids are handled properly when loading an initial down mirror file" do
    mirror_data = nil
    online_id_of_offline_rec = nil
    in_online_app do
      another_online_record = GroupOwnedRecord.create(:description => "Yet Another", :group => @online_group)
      another_offline_rec = GroupOwnedRecord.new(:description => "One More", :group => @offline_group)
      force_save_and_reload(another_offline_rec)
      online_id_of_offline_rec = another_offline_rec.id
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      rec = GroupOwnedRecord.find_by_description("One More")
      assert_equal online_id_of_offline_rec, rec.id
      rec.description = "Back To The Future"
      rec.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal nil, GroupOwnedRecord.find_by_description("One More")
      assert_equal "Back To The Future", GroupOwnedRecord.find(online_id_of_offline_rec).description
    end
  end

  online_test "initial down mirror files do not include deletion entries" do
    global_record = GlobalRecord.create(:title => "Something")
    global_record.destroy

    str = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = Offroad::CargoStreamer.new(str, "r")
    deletion_cargo_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GlobalRecord)
    assert_equal false, cs.has_cargo_named?(deletion_cargo_name)
  end

  cross_test "cannot import up mirror files with invalid records" do
    mirror_data = nil
    in_offline_app do
      group_rec = GroupOwnedRecord.new(:description => "Invalid record", :group => @offline_group, :should_be_even => 3)
      group_rec.save_without_validation
      mirror_data = Offroad::MirrorData.new(@offline_group, :skip_write_validation => true).write_upwards_data
    end

    in_online_app do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot import down mirror files with invalid records" do
    mirror_data = nil
    in_online_app do
      global_rec = GlobalRecord.new(:title => "Invalid record", :should_be_odd => 2)
      global_rec.save_without_validation
      mirror_data = Offroad::MirrorData.new(@offline_group, :skip_write_validation => true).write_downwards_data
    end

    in_offline_app do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "cannot import initial down mirror files with invalid records" do
    mirror_data = nil
    in_online_app do
      group_rec = GroupOwnedRecord.new(:description => "Invalid record", :group => @online_group, :should_be_even => 3)
      group_rec.save_without_validation
      @online_group.group_offline = true
      writer = Offroad::MirrorData.new(@online_group, :skip_write_validation => true, :initial_mode => true)
      mirror_data = writer.write_downwards_data
    end

    in_offline_app(false, true) do
      assert_raise Offroad::DataError do
        Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      end
    end
  end

  cross_test "foreign keys are transformed correctly on up mirror" do
    in_online_app do
      # Perturb the autoincrement a bit
      GroupOwnedRecord.create(:description => "Alice", :group => @online_group)
      GroupOwnedRecord.create(:description => "Bob", :group => @online_group)
    end

    mirror_data = nil
    in_offline_app do
      parent = GroupOwnedRecord.create(:description => "Celia", :group => @offline_group)
      child_a = GroupOwnedRecord.create(:description => "Daniel", :parent => parent, :group => @offline_group)
      child_b = GroupOwnedRecord.create(:description => "Eric", :parent => parent, :group => @offline_group)
      grandchild = GroupOwnedRecord.create(:description => "Fran", :parent => child_b, :group => @offline_group)
      time_traveler = GroupOwnedRecord.create(:description => "Philip J. Fry", :group => @offline_group)
      time_traveler.parent = time_traveler
      time_traveler.save!
      @offline_group.favorite = grandchild
      @offline_group.save!
      @offline_group_data.parent = grandchild
      @offline_group_data.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)

      @offline_group.reload
      @offline_group_data.reload
      parent = GroupOwnedRecord.find_by_description("Celia")
      child_a = GroupOwnedRecord.find_by_description("Daniel")
      child_b = GroupOwnedRecord.find_by_description("Eric")
      grandchild = GroupOwnedRecord.find_by_description("Fran")
      time_traveler = GroupOwnedRecord.find_by_description("Philip J. Fry")

      assert_equal parent, child_a.parent
      assert_equal parent, child_b.parent
      assert_equal child_b, grandchild.parent
      assert_equal grandchild, child_b.children.first
      assert_equal grandchild, @offline_group.favorite
      assert_equal @offline_group_data, grandchild.children.first
      assert_equal grandchild, @offline_group_data.parent
      assert_equal time_traveler, time_traveler.parent
    end
  end

  cross_test "foreign keys are transformed correctly on down mirror" do
    mirror_data = nil
    in_online_app do
      alice = GlobalRecord.create(:title => "Alice")
      alice.friend = alice
      alice.save!
      bob = GlobalRecord.create(:title => "Bob", :friend => alice)
      claire = GlobalRecord.create(:title => "Claire", :friend => bob)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      alice = GlobalRecord.find_by_title("Alice")
      bob = GlobalRecord.find_by_title("Bob")
      claire = GlobalRecord.find_by_title("Claire")
      assert_equal alice, alice.friend
      assert_equal alice, bob.friend
      assert_equal bob, claire.friend
    end
  end

  cross_test "loading up mirror file loads group state information" do
    in_online_app do
      assert_equal "Unknown", @offline_group.group_state.operating_system
    end

    mirror_data = nil
    offline_os = ""
    in_offline_app do
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
      offline_os = @offline_group.group_state.operating_system
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal offline_os, @offline_group.group_state.operating_system
    end
  end

  offline_test "creating up mirror file increments current_mirror_version" do
    prior_version = Offroad::SystemState::current_mirror_version
    Offroad::MirrorData.new(@offline_group).write_upwards_data
    assert_equal prior_version+1, Offroad::SystemState::current_mirror_version
  end

  online_test "creating down mirror file increments current_mirror_version" do
    prior_version = Offroad::SystemState::current_mirror_version
    Offroad::MirrorData.new(@offline_group).write_downwards_data
    assert_equal prior_version+1, Offroad::SystemState::current_mirror_version
  end

  online_test "creating initial down mirror file increments current_mirror_version" do
    prior_version = Offroad::SystemState::current_mirror_version
    Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    assert_equal prior_version+1, Offroad::SystemState::current_mirror_version
  end

  cross_test "receiving an up mirror file increments confirmed_group_data_version to the indicated value if larger" do
    mirror_data = nil
    in_offline_app do
      @offline_group_data.description = "New Name"
      @offline_group_data.save!

      Offroad::SystemState::instance_record.update_attribute(:current_mirror_version, 42)

      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      assert_equal 1, @offline_group.group_state.confirmed_group_data_version
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_equal 42, @offline_group.group_state.confirmed_group_data_version
    end
  end

  cross_test "received up mirror files are rejected if their version is equal to or lower than current version" do
    [42, 41].each do |sending_version|
      mirror_data = nil
      in_offline_app(true) do
        @offline_group_data.description = "New Name"
        @offline_group_data.save!

        Offroad::SystemState::instance_record.update_attribute(:current_mirror_version, sending_version)

        mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
      end

      in_online_app do
        group_state = @offline_group.group_state
        group_state.confirmed_group_data_version = 42
        group_state.save!

        assert_raise Offroad::OldDataError do
          Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
        end
      end
    end
  end

  cross_test "receiving a down mirror file increments confirmed_global_data_version to the indicated value if larger" do
    mirror_data = nil
    in_online_app do
      GlobalRecord.create(:title => "Testing")

      Offroad::SystemState::instance_record.update_attribute(:current_mirror_version, 42)

      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      assert_equal 1, @offline_group.group_state.confirmed_global_data_version
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      assert_equal 42, @offline_group.group_state.confirmed_global_data_version
    end
  end

  cross_test "received down mirror files are rejected if their version is equal to or lower than current version" do
    [42, 41].each do |sending_version|
      mirror_data = nil
      in_online_app do
        GlobalRecord.create(:title => "Testing")

        Offroad::SystemState::instance_record.update_attribute(:current_mirror_version, sending_version)

        mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
      end

      in_offline_app do
        group_state = @offline_group.group_state
        group_state.confirmed_global_data_version = 42
        group_state.save!

        assert_raise Offroad::OldDataError do
          Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
        end
      end
    end
  end

  cross_test "after loading initial down mirror file global_data_version matches online prior current_mirror_version" do
    mirror_data = nil
    online_version = nil
    in_online_app do
      Offroad::SystemState::instance_record.update_attribute(:current_mirror_version, 3)
      online_version = Offroad::SystemState::current_mirror_version
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app(false, true) do
      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      assert_equal online_version, @offline_group.group_state.confirmed_global_data_version
    end
  end

  cross_test "down mirror files do not include records which offline is known to already have the latest version of" do
    mirror_data = nil
    in_online_app do
      GlobalRecord.create!(:title => "Record A", :some_boolean => false)
      GlobalRecord.create!(:title => "Record B", :some_boolean => false)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      rec_a = GlobalRecord.find_by_title("Record A")
      rec_a.some_boolean = true
      rec_a.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    cs = Offroad::CargoStreamer.new(mirror_data, "r")
    recs = []
    cs.each_cargo_section(Offroad::MirrorData.send(:data_cargo_name_for_model, GlobalRecord)) do |batch|
      recs += batch
    end
    assert_equal 1, recs.size
    assert_equal "Record A", recs[0].title
    assert_equal true, recs[0].some_boolean
  end

  cross_test "up mirror files do not include records which online is known to already have the latest version of" do
    mirror_data = nil
    in_offline_app do
      GroupOwnedRecord.create!(:description => "Another Record", :group => @offline_group)
      @offline_group_data.description = "Changed"
      @offline_group_data.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      @offline_group_data.description = "Changed Again"
      @offline_group_data.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    cs = Offroad::CargoStreamer.new(mirror_data, "r")
    recs = []
    cs.each_cargo_section(Offroad::MirrorData.send(:data_cargo_name_for_model, GroupOwnedRecord)) do |batch|
      recs += batch
    end
    assert_equal 1, recs.size
    assert_equal "Changed Again", recs[0].description
  end

  offline_test "changed records are re-included in new up mirror files if their reception is not confirmed" do
    @offline_group_data.description = "Changed"
    @offline_group_data.save!

    2.times do
      cs = Offroad::CargoStreamer.new(Offroad::MirrorData.new(@offline_group).write_upwards_data, "r")
      assert_single_model_cargo_entry_matches(cs, @offline_group_data)
    end
  end

  online_test "changed records are re-included in new down mirror files if their reception is not confirmed" do
    global_rec = GlobalRecord.create(:title => "Testing")

    2.times do
      cs = Offroad::CargoStreamer.new(Offroad::MirrorData.new(@offline_group).write_downwards_data, "r")
      assert_single_model_cargo_entry_matches(cs, global_rec)
    end
  end

  cross_test "up mirror files do not include deletion requests for records known to be deleted on online system" do
    sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GroupOwnedRecord)

    mirror_data = nil
    in_offline_app do
      @offline_group_data.destroy
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    assert_equal 1, all_records_from_section_named(Offroad::CargoStreamer.new(mirror_data, "r"), sec_name).size

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    assert_equal 0, all_records_from_section_named(Offroad::CargoStreamer.new(mirror_data, "r"), sec_name).size
  end

  cross_test "down mirror files do not include deletion requests for records known to be deleted on offline system" do
    sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GlobalRecord)

    mirror_data = nil
    in_online_app do
      GlobalRecord.create(:title => "Testing")
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      GlobalRecord.find_by_title("Testing").destroy
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    assert_equal 1, all_records_from_section_named(Offroad::CargoStreamer.new(mirror_data, "r"), sec_name).size

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    assert_equal 0, all_records_from_section_named(Offroad::CargoStreamer.new(mirror_data, "r"), sec_name).size
  end

  offline_test "deletions are re-included in new up mirror files if their reception is not confirmed" do
    sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GroupOwnedRecord)
    @offline_group_data.destroy

    2.times do
      cs = Offroad::CargoStreamer.new(Offroad::MirrorData.new(@offline_group).write_upwards_data, "r")
      assert_equal 1, all_records_from_section_named(cs, sec_name).size
    end
  end

  cross_test "deletions are re-included in new down mirror files if their reception is not confirmed" do
    mirror_data = nil
    in_online_app do
      global_rec = GlobalRecord.create(:title => "Testing")
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)

      GlobalRecord.find_by_title("Testing").destroy
      sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GlobalRecord)
      2.times do
        cs = Offroad::CargoStreamer.new(Offroad::MirrorData.new(@offline_group).write_downwards_data, "r")
        assert_equal 1, all_records_from_section_named(cs, sec_name).size
      end
    end
  end

  online_test "records from other offline groups are not included in initial down mirror files" do
    another_offline_group = Group.create(:name => "One More Offline Group")
    data = GroupOwnedRecord.create(:description => "One More Offline Data", :group => another_offline_group)
    another_offline_group.group_offline = true
    mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    cs = Offroad::CargoStreamer.new(mirror_data, "r")
    assert_record_not_present(cs, data)
  end

  cross_test "protected attributes can be updated from up mirror files" do
    mirror_data = nil
    in_offline_app do
      @offline_group_data.protected_integer = 123
      @offline_group_data.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      assert_not_equal 123, @offline_group_data.protected_integer
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      @offline_group_data.reload
      assert_equal 123, @offline_group_data.protected_integer
    end
  end

  cross_test "protected attributes can be updated from down mirror files" do
    mirror_data = nil
    in_online_app do
      GlobalRecord.create(:title => "Testing")
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      grec = GlobalRecord.find_by_title("Testing")
      grec.protected_integer = 789
      grec.save!
      mirror_data = Offroad::MirrorData.new(@offline_group).write_downwards_data
    end

    in_offline_app do
      assert_not_equal 789, GlobalRecord.find_by_title("Testing").protected_integer
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)
      assert_equal 789, GlobalRecord.find_by_title("Testing").protected_integer
    end
  end

  cross_test "cannot use an up mirror file to delete the group record itself" do
    mirror_data = nil
    in_offline_app do
      mirror_data = StringIO.open do |sio|
        cs = Offroad::CargoStreamer.new(sio, "w")
        Offroad::MirrorData.new(@offline_group).write_upwards_data(cs)

        sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, Group)
        deletion_srs = Offroad::SendableRecordState.for_record(@offline_group).first
        deletion_srs.deleted = true
        cs.write_cargo_section(sec_name, [deletion_srs])

        sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GroupOwnedRecord)
        deletion_srs = Offroad::SendableRecordState.for_record(@offline_group_data).first
        deletion_srs.deleted = true
        cs.write_cargo_section(sec_name, [deletion_srs])

        sio.string
      end
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)
      assert_nil GroupOwnedRecord.find_by_description("Sam") # Make sure the deletion faking method actually works...
      assert_not_nil Group.find_by_name("An Offline Group") # Except on group base records
    end
  end

  cross_test "after loading an initial down mirror file only changed records appear in up mirror" do
    mirror_data = nil
    in_online_app do
      mirror_data = Offroad::MirrorData.new(@offline_group, :initial_mode => true).write_downwards_data
    end

    in_offline_app(false, true) do
      Offroad::MirrorData.new(nil, :initial_mode => true).load_downwards_data(mirror_data)
      group = Group.first
      group.name = "Weird Al"
      group.save!
      group.reload
      mirror_data = Offroad::MirrorData.new(group).write_upwards_data
      cs = Offroad::CargoStreamer.new(mirror_data, "r")
      assert_single_model_cargo_entry_matches(cs, group)
      assert_record_not_present(cs, GroupOwnedRecord.first)
    end
  end

  cross_test "cannot affect group records in offline app using a non-initial down mirror file" do
    mirror_data = nil
    in_online_app do
      mirror_data = StringIO.open do |sio|
        cs = Offroad::CargoStreamer.new(sio, "w")
        Offroad::MirrorData.new(@offline_group).write_downwards_data(cs)

        grec = GlobalRecord.create(:title => "Testing 123")
        sec_name = Offroad::MirrorData.send(:data_cargo_name_for_model, GlobalRecord)
        cs.write_cargo_section(sec_name, [grec])

        sec_name = Offroad::MirrorData.send(:data_cargo_name_for_model, GroupOwnedRecord)
        new_rec = GroupOwnedRecord.new(:description => "Brand New Thing", :group => @offline_group)
        new_rec.id = 1234
        cs.write_cargo_section(sec_name, [new_rec])

        sec_name = Offroad::MirrorData.send(:deletion_cargo_name_for_model, GroupOwnedRecord)
        deletion_srs = Offroad::SendableRecordState.for_record(@offline_group_data).new
        deletion_srs.deleted = true
        cs.write_cargo_section(sec_name, [deletion_srs])

        sio.string
      end
    end

    in_offline_app do
      Offroad::MirrorData.new(@offline_group).load_downwards_data(mirror_data)

      # Make sure the section faking method actually works...
      assert_not_nil GlobalRecord.find_by_title("Testing 123")

      # Except on group records
      assert_nil GroupOwnedRecord.find_by_description("Brand New Thing")
      assert_not_nil GroupOwnedRecord.find_by_description("Sam")
    end
  end

  cross_test "can transfer self-referencing records" do
    mirror_data = nil
    in_offline_app do
      # Create a new self-referencing record
      new_self_ref = GroupOwnedRecord.create(:description => "Phillip J. Fry", :group => @offline_group)
      new_self_ref.parent = new_self_ref
      new_self_ref.save!
      assert_equal new_self_ref.id, new_self_ref.parent.id

      # Alter an existing record to be self-referencing
      @offline_group_data.parent = @offline_group_data
      @offline_group_data.save!

      mirror_data = Offroad::MirrorData.new(@offline_group).write_upwards_data
    end

    in_online_app do
      Offroad::MirrorData.new(@offline_group).load_upwards_data(mirror_data)

      fry = GroupOwnedRecord.find_by_description("Phillip J. Fry")
      assert fry
      assert_equal fry.id, fry.parent.id

      @offline_group_data.reload
      assert_equal @offline_group_data.id, @offline_group_data.parent.id
    end
  end
end
