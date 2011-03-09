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
end
