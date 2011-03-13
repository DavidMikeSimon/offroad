require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This just tests the controller's ability to properly access the functionality of the MirrorData class
# Tests for the actual generation and processing of mirror files are in mirror_data_test.rb

class GroupControllerTest < ActionController::TestCase
  online_test "can retrieve a down mirror file for the offline group" do
    get :download_down_mirror, "id" => @offline_group.id
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("downloaded from the Test App online system"), "testapp's down mirror view file used"
    
    StringIO.open(content) do |sio|
      cs = Offroad::CargoStreamer.new(sio, "r")
      mirror_info = cs.first_cargo_element("mirror_info")
      assert mirror_info.app_mode.downcase.include?("online")
      assert_equal false, mirror_info.initial_file
    end
  end
  
  online_test "can retrieve an initial down mirror file for the offline group" do
    get :download_initial_down_mirror, "id" => @offline_group.id
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("downloaded from the Test App online system"), "testapp's down mirror view file used"
    
    StringIO.open(content) do |sio|
      cs = Offroad::CargoStreamer.new(sio, "r")
      mirror_info = cs.first_cargo_element("mirror_info")
      assert mirror_info.app_mode.downcase.include?("online")
      assert mirror_info.initial_file
    end
  end
  
  offline_test "can retrieve an up mirror file for the offline group" do
    get :download_up_mirror, "id" => @offline_group.id
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("to the Test App online system"), "testapp's up mirror view file was used"
    
    # This tests ViewHelper::link_to_online_app, used from the testapp's up mirror view
    assert content.include?(">" + Offroad::online_url + "</a>")
    assert content.include?("href=\"" + Offroad::online_url + "\"")
    
    StringIO.open(content) do |sio|
      cs = Offroad::CargoStreamer.new(sio, "r")
      assert cs.first_cargo_element("mirror_info").app_mode.downcase.include?("offline")
    end
  end
  
  online_test "cannot retrieve up mirror files" do
    assert_raise Offroad::PluginError do
      get :download_up_mirror, "id" => @offline_group.id
    end
  end
  
  online_test "cannot retrieve down mirror files for online groups" do
    assert_raise Offroad::PluginError do
      get :download_down_mirror, "id" => @online_group.id
    end
  end
  
  cross_test "can upload up mirror files" do
    mirror_data = ""
    in_offline_app do
      @offline_group.name = "ABC"
      @offline_group.save!
      get :download_up_mirror, "id" => @offline_group.id
      mirror_data = @response.binary_content
    end
    
    in_online_app do
      post :upload_up_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
      assert_response :success
      @offline_group.reload
      assert_equal "ABC", @offline_group.name
    end
  end
  
  offline_test "can upload down mirror files" do
    mirror_data = ""
    in_online_app do
      GlobalRecord.create!(:title => "123")
      get :download_down_mirror, "id" => @offline_group.id
      mirror_data = @response.binary_content
    end
    
    in_offline_app do
      assert_equal 0, GlobalRecord.count
      post :upload_down_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
      assert_response :success
      assert_equal 1, GlobalRecord.count
      assert_equal "123", GlobalRecord.first.title
    end
  end
    
  cross_test "can upload initial down mirror files" do
    mirror_data = ""
    in_online_app do
      get :download_initial_down_mirror, "id" => @offline_group.id
      mirror_data = @response.binary_content
    end
    
    in_offline_app(false, true) do
      assert_equal 0, Group.count
      post :upload_initial_down_mirror, "mirror_data" => mirror_data
      assert_equal 1, Group.count
    end
  end
  
  offline_test "cannot retrieve down mirror files" do
    assert_raise Offroad::PluginError do
      get :download_down_mirror, {"id" => @offline_group.id}
    end
  end
  
  offline_test "cannot upload up mirror files" do
    get :download_up_mirror, "id" => @offline_group.id
    mirror_data = @response.binary_content
    
    assert_raise Offroad::PluginError do
      post :upload_up_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
    end
  end
  
  online_test "cannot upload down mirror files" do
    get :download_down_mirror, "id" => @offline_group.id
    mirror_data = @response.binary_content
    
    assert_raise Offroad::PluginError do
      post :upload_down_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
    end
  end
  
  cross_test "cannot upload a mirror file for an online group" do
    mirror_data = ""
    in_offline_app do
      get :download_up_mirror, "id" => @offline_group.id
      mirror_data = @response.binary_content
    end
    
    in_online_app do
      @offline_group.group_offline = false
      assert_raise Offroad::PluginError do
        post :upload_up_mirror, "id" => @online_group.id, "mirror_data" => mirror_data
      end
    end
  end
end
