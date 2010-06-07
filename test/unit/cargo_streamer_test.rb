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
  
  common_test "can encode and retrieve a simple hash" do
    assert_round_trip_equality "a" => [1], "b" => [2]
  end
  
  common_test "can encode and retrieve an empty hash" do
    assert_round_trip_equality
  end
  
  common_test "uses an md5 fingerprint to detect corruption" do
    test_hash = {"foo bar narf bork" => [1]}
    str = generate_cargo_string test_hash
    
    md5sum = nil
    if str =~ /\b([0-9a-f]{32})\b/
      md5sum = $1
    end
    assert md5sum, "Generated string includes something that looks like an md5 fingerprint"
    assert_equal test_hash, retrieve_cargo_from_string(str), "Works with unmodified fingerprint"
    assert_raise OfflineMirror::CargoStreamerDataError, "Changing fingerprint causes exception to be raised" do
      retrieve_cargo_from_string(str.gsub md5sum, "a"*md5sum.size)
    end
    
    assert_raise OfflineMirror::CargoStreamerDataError, "Changing base64 content causes exception to be raised" do
      # This is somewhat of an implementation-dependent test; I checked manually that the data has this string in it.
      # It's safe, though, as changing the implementation-generated string should cause false neg, not false pos.
      retrieve_cargo_from_string(str.sub "BAAAM", "BAAAm")
    end
  end
end

run_test_class CargoStreamerTest