require File.dirname(__FILE__) + '/../test_helper'

class ModuleFuncsTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  online_test "app reports being offline" do
    assert OfflineMirror::app_online?, "App is online"
    assert_equal false, OfflineMirror::app_offline?, "App is not offline"
  end
  
  offline_test "app reports being offline" do
    assert OfflineMirror::app_offline?, "App is offline"
    assert_equal false, OfflineMirror::app_online?, "App is not online"
  end
  
  common_test "app reports correct version" do
    # TODO Implement
  end
  
  online_test "cannot call offline_group" do
    assert_raise OfflineMirror::PluginError do
      OfflineMirror::offline_group
    end
  end
  
  offline_test "offline_group returns the offline group" do
    assert_equal @offline_group, OfflineMirror::offline_group
  end
end

run_test_class ModuleFuncsTest