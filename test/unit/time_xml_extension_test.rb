require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the plugin's monkey patch to increase default precision on Time#xmlschema

class TimeXMLExtensionTest < ActiveSupport::TestCase
  online_test "time serialized to xml includes milliseconds" do
    $stderr.puts Time.now.xmlschema
    assert Time.now.xmlschema =~ /\d+:\d+\.\d+/
  end
  
  online_test "a time is unchanged by going thru xml and back" do
    orig_time = Time::parse("1:23:45.678").gmtime
    new_time = Time::xmlschema(orig_time.xmlschema)
    assert_equal orig_time, new_time
  end
end

run_test_class TimeXMLExtensionTest