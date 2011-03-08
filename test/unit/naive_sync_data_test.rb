require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle models in naive_sync mode 

class NaiveSyncDataTest < Test::Unit::TestCase
  double_test "can create new naive synced records" do
    assert_nothing_raised do
      NaiveSyncedRecord.create(:description => "Foobar")
    end
  end

  double_test "naive sync models report being synced data" do
    assert NaiveSyncedRecord.offroad_sync_data?
  end

  double_test "naive sync data is writable and destroyable" do
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    assert_nothing_raised do
      naive_rec.description = "Bork"
      naive_rec.save!
      naive_rec.destroy
    end
  end

  double_test "naive sync data models return true to acts_as_offroadable?" do
    assert NaiveSyncedRecord.acts_as_offroadable?
  end
end
