require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle models in group_single mode

class GroupSingleTest < Test::Unit::TestCase
  def setup
    super
    self.class.const_set("GroupSingleRecord", Class.new(ActiveRecord::Base))
    GroupSingleRecord.send(:acts_as_offroadable, :group_single)
  end

  def teardown
    # Manually remove the group_single model after the test is done.
    # Otherwise no other tests will be able to work with multiple groups
    Offroad.send(:class_variable_set, :@@group_single_models, {})
    self.class.send(:remove_const, "GroupSingleRecord")
    super
  end

  empty_online_test "can create, alter, and destroy group single records if there are no offline groups" do
    assert_nothing_raised do
      rec = GroupSingleRecord.create(:description => "Foo")
      rec.description = "Bar"
      rec.save!
      rec.destroy
    end
  end

  empty_online_test "cannot create, alter, or destroy group single records if there are any offline groups" do
    rec = GroupSingleRecord.create(:description => "Foo")
    group = Group.create(:name => "Test Group")
    group.group_offline = true

    assert_raise ActiveRecord::ReadOnlyRecord do
      GroupSingleRecord.create(:description => "Bar")
    end

    assert_raise ActiveRecord::ReadOnlyRecord do
      rec.description = "Bar"
      rec.save!
    end

    assert_raise ActiveRecord::ReadOnlyRecord do
      rec.destroy
    end
  end

  empty_online_test "group single records belong to nil if no groups are offline" do
    rec = GroupSingleRecord.create(:description => "Foo")
    assert_equal nil, rec.owning_group
  end

  empty_online_test "group single records belong to first offline group" do
    rec = GroupSingleRecord.create(:description => "Foo")
    group_a = Group.create(:name => "A")
    group_b = Group.create(:name => "B")

    group_a.group_offline = true
    assert_equal group_a, rec.owning_group
    group_a.group_offline = false
    group_b.group_offline = true
    assert_equal group_b, rec.owning_group
  end

  empty_online_test "cannot set more than one group offline if any group single models exist" do
    group_a = Group.create(:name => "A")
    group_b = Group.create(:name => "B")

    group_a.group_offline = true
    assert_raise Offroad::DataError do
      group_b.group_offline = true
    end
    group_a.group_offline = false
    group_b.group_offline = true
    assert_raise Offroad::DataError do
      group_a.group_offline = true
    end
  end
end
