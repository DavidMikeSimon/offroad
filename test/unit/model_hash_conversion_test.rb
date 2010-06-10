require File.dirname(__FILE__) + '/../test_helper'

# This is a unit test on the ability of model_extensions to convert records to and from simple hashes

class ModelHashConversionTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  common_test "can convert a record to a simple attributes hash and back again" do
    hash = @offline_group.simplified_attributes
    group = Group.new
    assert_not_equal group, @offline_group
    group.load_from_simplified_attributes(hash)
    assert_equal group, @offline_group
  end
  
  common_test "times in a model are converted to timestamp integers in a simple attributes hash" do
    hash = @offline_group.simplified_attributes
    assert_equal @offline_group.updated_at.to_i, hash["updated_at"]
  end
end

run_test_class ModelHashConversionTest