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
end

run_test_class CargoStreamerTest