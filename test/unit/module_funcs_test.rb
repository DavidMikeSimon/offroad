require File.dirname(__FILE__) + '/../test_helper'

class ModuleFuncsTest < Test::Unit::TestCase
  online_test "app reports being online" do
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
  
  agnostic_test "config_app_online can set app to online or offline" do
    OfflineMirror::config_app_online(true)
    assert OfflineMirror::app_online?
    OfflineMirror::config_app_online(false)
    assert OfflineMirror::app_offline?
  end
  
  agnostic_test "config_app_online with nil sets app to unknown mode, which raises exception when checked" do
    OfflineMirror::config_app_online(nil)
    assert_raise OfflineMirror::AppModeUnknownError do
      OfflineMirror::app_online?
    end
  end
end