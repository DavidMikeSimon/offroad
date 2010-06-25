require File.dirname(__FILE__) + '/../test_helper'

class TestFrameworkTest < Test::Unit::TestCase
  cross_test "online and offline databases are independent" do
    flunk
  end
  
  cross_test "online and offline instance variables are independent" do
    flunk
  end
  
  cross_test "instance variables lose unsaved data on mode switch" do
    flunk
  end
end