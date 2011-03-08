require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle models in naive_sync mode 

class NaiveSyncDataTest < Test::Unit::TestCase
  double_test "naive sync models report being synced data" do
    assert NaiveSyncedRecord.offroad_sync_data?
  end
end
