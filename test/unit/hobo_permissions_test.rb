require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This is a unit test on the ability of model_extensions to override regular Hobo model permissions

class HoboPermissionsTest < Test::Unit::TestCase
  if HOBO_TEST_MODE
    def setup
      @guest = Guest.new
      super
    end

    class HoboPermissionsTestModel < ActiveRecord::Base
      hobo_model
      set_table_name "broken_records"

      def create_permitted?
        true
      end

      def update_permitted?
        true
      end

      def destroy_permitted?
        true
      end

      acts_as_offroadable :global
    end
  end

  offline_test "can override hobo permissions" do
    if HOBO_TEST_MODE
      rec = HoboPermissionsTestModel.new
      force_save_and_reload(rec)

      # We are in offline mode and rec is offroad as global
      # Therefore we should not be able to edit it
      assert !rec.creatable_by?(@guest)
      assert !rec.updatable_by?(@guest)
      assert !rec.destroyable_by?(@guest)
    end
  end

  online_test "overriding hobo permissions does not block off user specified permissions" do
    if HOBO_TEST_MODE
      rec = HoboPermissionsTestModel.new
      force_save_and_reload(rec)

      # We are in offline mode and rec is offroad as global
      # Therefore we should be able to edit it
      assert rec.creatable_by?(@guest)
      assert rec.updatable_by?(@guest)
      assert rec.destroyable_by?(@guest)
    end
  end
end
