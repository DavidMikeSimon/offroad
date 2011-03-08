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

  double_test "cannot change id of naive sync data" do
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    assert_raise Offroad::DataError do
      naive_rec.id += 1
      naive_rec.save!
    end
  end

  double_test "naive sync data can hold a foreign key to other naive sync data" do
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    other_rec = NaiveSyncedRecord.create(:description => "Other")
    assert_nothing_raised do
      naive_rec.buddy = other_rec
      naive_rec.save!
    end
  end

  online_test "naive sync data can hold a foreign key to global data" do
    # This is an online test because an offline app cannot create global records
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    global_rec = GlobalRecord.create(:title => "Something")
    assert_nothing_raised do
      naive_rec.global_record = global_rec
      naive_rec.save!
    end
  end
  
  double_test "naive sync data can hold a foreign key to group data" do
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    assert_nothing_raised do
      naive_rec.group = @editable_group
      naive_rec.group_owned_record = @editable_group_data
      naive_rec.save!
    end
  end

  double_test "naive sync data cannot hold a foreign key to unmirrored data" do
    naive_rec = NaiveSyncedRecord.create(:description => "Foobar")
    unmirrored_data = UnmirroredRecord.create(:content => "Some Unmirrored Data")
    assert_raise Offroad::DataError do
      naive_rec.unmirrored_record = unmirrored_data
      naive_rec.save!
    end
  end

  double_test "naive sync data models return true to acts_as_offroadable?" do
    assert NaiveSyncedRecord.acts_as_offroadable?
  end
end
