require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ModuleFuncsTest < Test::Unit::TestCase
  online_test "app reports being online" do
    assert Offroad::app_online?, "App is online"
    assert_equal false, Offroad::app_offline?, "App is not offline"
  end
  
  offline_test "app reports being offline" do
    assert Offroad::app_offline?, "App is offline"
    assert_equal false, Offroad::app_online?, "App is not online"
  end
  
  online_test "cannot call offline_group" do
    assert_raise Offroad::PluginError do
      Offroad::offline_group
    end
  end
  
  offline_test "offline_group returns the offline group" do
    assert_equal @offline_group, Offroad::offline_group
  end
  
  agnostic_test "config_app_online can set app to online or offline" do
    Offroad::config_app_online(true)
    assert Offroad::app_online?
    Offroad::config_app_online(false)
    assert Offroad::app_offline?
  end
  
  agnostic_test "config_app_online with nil sets app to unknown mode, which raises exception when checked" do
    Offroad::config_app_online(nil)
    assert_raise Offroad::AppModeUnknownError do
      Offroad::app_online?
    end
  end
end
