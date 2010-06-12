require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the plugin's monkey patch to increase default precision on Time classes' xmlschema methods

class TimeXMLExtensionTest < ActiveSupport::TestCase
  def for_each_time_class
    [Time, ActiveSupport::TimeZone.new("UTC")].each do |cls|
      yield cls
    end
  end
  
  online_test "time serialized to xml includes milliseconds" do
    for_each_time_class do |cls|
      assert cls.now.xmlschema =~ /\d+:\d+\.\d+/, "serialization ms check for #{cls.name}"
    end
  end
  
  online_test "a time is unchanged by going thru xml and back" do
    for_each_time_class do |cls|
      orig_time = cls::parse("1:23:45.678")
      new_time = Time::xmlschema(orig_time.xmlschema)
      assert_equal orig_time, new_time, "encoding change check for #{cls.name}"
    end
  end
end

run_test_class TimeXMLExtensionTest