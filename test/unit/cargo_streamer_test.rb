require File.dirname(__FILE__) + '/../test_helper'

class CargoStreamerTest < ActiveSupport::TestCase
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
  
  def assert_round_trip_equality(hash = {})
    assert_equal hash, round_trip(hash)
  end
  
  common_test "can encode and retrieve simple data" do
    assert_round_trip_equality "a" => [[1]], "b" => [[2]]
  end
  
  common_test "can encode and retrieve an empty hash" do
    assert_round_trip_equality "a" => [{}]
  end
  
  common_test "can decode cargo data even if there is other stuff around it" do
    test_hash = {"foo bar narf bork" => [[1]]}
    str = "BLAH BLAH BLAH" + generate_cargo_string(test_hash) + "BAR BAR BAR"
    assert_equal test_hash, retrieve_cargo_from_string(str)
  end
  
  common_test "can correctly identify the names of the cargo sections" do
    test_hash = {"abc" => [[1]], "xyz" => [[2]]}
    str = generate_cargo_string test_hash
    StringIO.open(str) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_equal test_hash.keys, cs.cargo_section_names
      assert cs.has_cargo_named?("abc")
      assert_equal false, cs.has_cargo_named?("foobar")
    end
  end
  
  common_test "can create and retrieve multiple ordered cargo sections with the same name" do
    test_data = [[1, 2], [3, 4], ["a", "b"]]
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
    
    assert_equal test_data, result_data
  end
  
  common_test "can use first_cargo_section to get only the first section with a given name" do
    result = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      for i in 1..3 do
        cs.write_cargo_section("testing", ["item number #{i}"])
      end
      sio.string
    end
    
    StringIO.open(result) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert_equal ["item number 1"], cs.first_cargo_section("testing")
      assert_equal nil, cs.first_cargo_section("no-such-section")
    end
  end
  
  common_test "can use :human_readable to include an unecoded version of a hash" do
    test_string = "Mares eat oats and does eat oats and little lambs eat ivy."
    result = StringIO.open do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "w")
      cs.write_cargo_section("test", {"foo" => test_string}, :human_readable => true)
      sio.string
    end
    assert result.include? test_string
  end
  
  common_test "cannot use :human_readable on non-hashes" do
    assert_raise OfflineMirror::CargoStreamerError do
      StringIO.open do |sio|
        cs = OfflineMirror::CargoStreamer.new(sio, "w")
        cs.write_cargo_section("test", ["test"], :human_readable => true)
      end
    end
  end
  
  common_test "cannot directly encode a value that's not in an array" do
    assert_raise OfflineMirror::CargoStreamerError do
      generate_cargo_string "foo" => [1]
    end
  end
  
  common_test "cannot encode self-referential structure" do
    arr_a = [1,2,3]
    arr_b = [4,5,6]
    arr_a << arr_b
    assert_nothing_raised do
      generate_cargo_string "blah" => [arr_a]
    end
    
    arr_b << arr_a
    assert_raise OfflineMirror::CargoStreamerError do
      generate_cargo_string "blah" => [arr_a]
    end
  end
  
  common_test "cannot encode a structure that's deeper than 4 levels" do
    a = [[[[["foo"]]]]]
    assert_nothing_raised do
      generate_cargo_string "blah" => [a]
    end
    assert_raise OfflineMirror::CargoStreamerError do
      generate_cargo_string "blah" => [[a]]
    end
  end
  
  common_test "uses an md5 fingerprint to detect corruption" do
    test_hash = {"foo bar narf bork" => [[1]]}
    str = generate_cargo_string test_hash
    
    md5sum = nil
    if str =~ /\b([0-9a-f]{32})\b/
      md5sum = $1
    end
    assert md5sum, "Generated string includes something that looks like an md5 fingerprint"
    assert_equal test_hash, retrieve_cargo_from_string(str), "Works with unmodified fingerprint"
    assert_raise OfflineMirror::CargoStreamerError, "Changing fingerprint causes exception to be raised" do
      retrieve_cargo_from_string(str.gsub md5sum, "a"*md5sum.size)
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Changing base64 content causes exception to be raised" do
      # This is somewhat of an implementation-dependent test; I checked manually that the data has this string in it.
      # It's safe, though, as changing the implementation-generated string should cause false neg, not false pos.
      retrieve_cargo_from_string(str.sub "owFAAH", "owFAAh")
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
      cs.write_cargo_section("test", "test")
    end
  end
  
  common_test "cannot use invalid cargo section names" do
    cs = OfflineMirror::CargoStreamer.new(StringIO.new, "w")
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for symbol cargo name" do
      cs.write_cargo_section(:test, "test")
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for cargo name that's bad in HTML comments" do
      cs.write_cargo_section("whatever--foobar", "test")
    end
    
    assert_raise OfflineMirror::CargoStreamerError, "Expect exception for cargo name that's multiline" do
      cs.write_cargo_section("whatever\nfoobar", "test")
    end
  end
  
  common_test "cannot directly encode a model instance" do
    rec = UnmirroredRecord.new(:content => "Test")
    assert_raise OfflineMirror::CargoStreamerError, "Should reject model at top layer" do
      generate_cargo_string "blah" => [rec]
    end
    assert_raise OfflineMirror::CargoStreamerError, "Should reject model even if it is deeply nested" do
      generate_cargo_string "blah" => [[[rec]]]
    end
    assert_nothing_raised "Should accept a hash of the model's data" do
      generate_cargo_string "blah" => [rec.attributes]
    end
  end
end

run_test_class CargoStreamerTest