require File.dirname(__FILE__) + '/../test_helper'

class CargoStreamerTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  def generate_cargo_string(hash)
    return StringIO.open do |sio|
      writer = OfflineMirror::CargoStreamer.new(sio, "w")
      hash.each do |key, arr|
        arr.each do |elem|
          writer.write_cargo_section(key, elem)
        end
      end
      
      sio.string
    end
  end
  
  def retrieve_cargo_from_string(str)
    return StringIO.open(str) do |sio|
      hash = {}
      
      reader = OfflineMirror::CargoStreamer.new(sio, "r")
      reader.cargo_section_names.each do |key|
        hash[key] = []
        reader.each_cargo_section(key) do |elem|
          hash[key] << elem
        end
      end
      
      hash
    end
  end
  
  def round_trip(hash = {})
    retrieve_cargo_from_string(generate_cargo_string(hash))
  end
  
  # Asserts content equality between two hashes of arrays of arrays of records.
  # Cannot just do new_hash == hash, because ActiveRecord#== always false when comparing two unsaved records.
  def assert_haar_equality(first_hash, second_hash)
    assert_nothing_raised do
      # Assert that they are subsets of each other
      [[first_hash, second_hash], [second_hash, first_hash]].each do |hash_a, hash_b|
        hash_a.each do |key, arr|
          arr.each_with_index do |subarr, i|
            subarr.each_with_index do |rec, j|
              rec.attributes.each_pair do |attr_key, attr_value|
                raise "Mismatch" unless attr_value == hash_b[key][i][j].attributes[attr_key]
              end
            end
          end
        end
      end
    end
  end
  
  def assert_round_trip_equality(hash = {})
    assert_haar_equality(hash, round_trip(hash))
  end
  
  def test_rec(str)
    GroupOwnedRecord.new(:description => str, :group => @editable_group)
  end
  
  common_test "can encode and retrieve a model instances in an array" do
    assert_round_trip_equality "test" => [[test_rec("A"), test_rec("B")]]
  end
  
  common_test "encoded models do not lose their id" do
    rec = test_rec("ABC")
    rec.id = 45
    decoded = round_trip "test" => [[rec]]
    assert_equal 45, decoded["test"][0][0].id
  end
  
  common_test "cannot encode and retrieve non-model data" do
    assert_raise OfflineMirror::CargoStreamerError do
      generate_cargo_string "a" => [[1]]
    end
  end
  
  common_test "cannot encode a model that is not in an array" do
    assert_raise OfflineMirror::CargoStreamerError do
      # This is not "in an array" for CargoStreamer; look at how generate_cargo_string is implemented
      generate_cargo_string "a" => [test_rec("Test")]
    end
  end
  
  common_test "can decode cargo data even if there is other stuff around it" do
    test_hash = {"foo bar narf bork" => [[test_rec("Test")]]}
    str = "BLAH BLAH BLAH" + generate_cargo_string(test_hash) + "BAR BAR BAR"
    assert_haar_equality test_hash, retrieve_cargo_from_string(str)
  end
  
  common_test "can correctly identify the names of the cargo sections" do
    test_hash = {"abc" => [[test_rec("A")]], "xyz" => [[test_rec("X")]]}
    str = generate_cargo_string test_hash
    StringIO.open(str) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_equal test_hash.keys, cs.cargo_section_names
      assert cs.has_cargo_named?("abc")
      assert_equal false, cs.has_cargo_named?("foobar")
    end
  end
  
  common_test "can create and retrieve multiple ordered cargo sections with the same name" do
    test_data = [[test_rec("a"), test_rec("b")], [test_rec("c"), test_rec("d")], [test_rec("e"), test_rec("f")]]
   
    str = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      test_data.each do |dat|
        cs.write_cargo_section("xyz", dat)
      end
      sio.string
    end
    
    result_data = []
    StringIO.open(str) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      cs.each_cargo_section "xyz" do |dat|
        result_data << dat
      end
    end
    
    assert_haar_equality({"test" => test_data}, {"test" => result_data})
  end
  
  common_test "can use first_cargo_section to get only the first section with a given name" do
    result = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      for i in 1..3 do
        cs.write_cargo_section("testing", [test_rec("item number #{i}")])
      end
      sio.string
    end
    
    StringIO.open(result) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_equal test_rec("item number 1").attributes, cs.first_cargo_section("testing")[0].attributes
      assert_equal nil, cs.first_cargo_section("no-such-section")
    end
  end
  
  common_test "can use :human_readable to include a string version of a record" do
    rec = test_rec("ABCD") # Note that GroupOwnedRecord overloads to_s
    
    result = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      cs.write_cargo_section("test", [rec], :human_readable => false)
      sio.string
    end
    assert_equal false, result.include?(rec.to_s)
    
    result = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      cs.write_cargo_section("test", [rec], :human_readable => true)
      sio.string
    end
    assert result.include?(rec.to_s)
  end
  
  common_test "uses an md5 fingerprint to detect corruption" do
    str = generate_cargo_string "test" => [[test_rec("abc")]]
    
    md5sum = nil
    if str =~ /\b([0-9a-f]{32})\b/
      md5sum = $1
    else
      flunk "Unable to find an md5sum in the generated string"
    end
    assert_raise OfflineMirror::CargoStreamerError, "Changing fingerprint causes exception to be raised" do
      retrieve_cargo_from_string(str.gsub md5sum, "a"*md5sum.size)
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Changing base64 content causes exception to be raised" do
      # This is somewhat of an implementation-dependent test; I checked manually that the data has this string in it.
      # It's safe, though, as changing the implementation should cause false neg, not false pos.
      retrieve_cargo_from_string(str.sub "WEGCJb", "WEGCJB")
    end
  end
  
  common_test "modes r and w work, other modes do not" do
    assert_nothing_raised "Mode r works" do
      OfflineMirror::CargoStreamer.new(StringIO.new(), "r")
    end
    
    assert_nothing_raised "Mode w works" do
      OfflineMirror::CargoStreamer.new(StringIO.new(), "w")
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Mode a doesn't work" do
      OfflineMirror::CargoStreamer.new(StringIO.new(), "a")
    end
  end
  
  common_test "cannot write cargo in read mode" do
    assert_raise OfflineMirror::CargoStreamerError do
      cs = OfflineMirror::CargoStreamer.new(StringIO.new, "r")
      cs.write_cargo_section("test", [test_rec("test")])
    end
  end
  
  common_test "cannot use invalid cargo section names" do
    cs = OfflineMirror::CargoStreamer.new(StringIO.new, "w")
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for symbol cargo name" do
      cs.write_cargo_section(:test, [test_rec("test")])
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for cargo name that's bad in HTML comments" do
      cs.write_cargo_section("whatever--foobar", [test_rec("test")])
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for cargo name that's multiline" do
      cs.write_cargo_section("whatever\nfoobar", [test_rec("test")])
    end
  end
  
  common_test "cannot trick cargo streamer into decoding a non-OfflineMirror model class" do
    rec = UnmirroredRecord.new(:content => "Stuff")
    str = generate_cargo_string "test" => [[rec]]
    assert_raise OfflineMirror::CargoStreamerError do
      retrieve_cargo_from_string(str)
    end
  end
end

run_test_class CargoStreamerTest