require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on model_extensions' additions to the to_xml method

class ModelXMLExtensionTest < ActiveSupport::TestCase
  online_test "model serialized to xml includes type name" do
    rec = Group.new(:name => "123")
    assert_equal false, rec.to_xml_without_type_inclusion.include?("Group")
    assert rec.to_xml.include?("Group")
  end
  
  online_test "can serialize an array of models" do
    assert_nothing_raised do
      Group.create(:name => "a")
      Group.create(:name => "b")
      Group.all.to_xml
    end
  end
end

run_test_class ModelXMLExtensionTest