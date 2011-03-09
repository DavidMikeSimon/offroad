require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to handle models in group_single mode

class GroupSingleTest < Test::Unit::TestCase
  cross_test "can create, alter, and destroy group single records if there are no offline groups" do
    in_online_app(false, true) do
      assert_nothing_raised do
        rec = GroupSingleRecord.create(:description => "Foo")
        rec.description = "Bar"
        rec.save!
        rec.destroy
      end
    end
  end

  cross_test "cannot create, alter, or destroy group single records if there are any offline groups" do
    in_online_app(false, true) do
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
  end

  cross_test "group single records belong to first offline group" do
    in_online_app(false, true) do
      rec = GroupSingleRecord.create(:description => "Foo")
      group_a = Group.create(:name => "A")
      group_b = Group.create(:name => "B")

      group_a.group_offline = true
      assert_equal group_a, rec.owning_group
      group_a.group_offline = false
      group_b.group_offline = true
      assert_equal group_b, rec.owning_group
    end
  end
end
