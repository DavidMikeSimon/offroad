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

  offline_test "can override hobo permissions on group base data" do
    if HOBO_TEST_MODE
      rec = HoboPermissionsTestModel.new
      force_save_and_reload(rec)
      assert !rec.destroyable_by?(@guest)
      assert !rec.updatable_by?(@guest)
    end
  end
end
