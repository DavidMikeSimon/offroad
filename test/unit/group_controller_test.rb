require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# This just tests the controller's ability to properly access the functionality of the MirrorData class
# Tests for the actual generation and processing of mirror files are in mirror_data_test.rb

class GroupControllerTest < ActionController::TestCase
  def gen_up_mirror_data(group)
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(group, [content, "w"], "offline")
    writer.write_upwards_data
    return content.string
  end
  
  def gen_down_mirror_data(group)
    content = StringIO.new
    writer = OfflineMirror::MirrorData.new(group, [content, "w"], "online")
    writer.write_downwards_data
    return content.string
  end
  
  online_test "can retrieve a down mirror file for the offline group" do
    get :download_down_mirror, "id" => @offline_group.id
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("downloaded from the Test App online system"), "testapp's down mirror view file used"
    
    StringIO.open(content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert cs.first_cargo_element("mirror_info").app_mode.downcase.include?("online")
    end
  end
  
  offline_test "can retrieve an up mirror file for the offline group" do
    get :download_up_mirror, "id" => @offline_group.id
    assert_response :success
    assert @response.headers["Content-Disposition"].include?("attachment")
    content = @response.binary_content
    assert content.include?("to the Test App online system"), "testapp's up mirror view file was used"
    
    # This tests ViewHelper::link_to_online_app, used from the testapp's up mirror view
    assert content.include?(">" + OfflineMirror::online_url + "</a>")
    assert content.include?("href=\"" + OfflineMirror::online_url + "\"")
    
    StringIO.open(content) do |sio|
      cs = OfflineMirror::CargoStreamer.new(sio, "r")
      assert cs.first_cargo_element("mirror_info").app_mode.downcase.include?("offline")
    end
  end
  
  online_test "cannot retrieve up mirror files" do
    assert_raise OfflineMirror::PluginError do
      get :download_up_mirror, "id" => @offline_group.id
    end
  end
  
  online_test "cannot retrieve down mirror files for online groups" do
    assert_raise OfflineMirror::PluginError do
      get :download_down_mirror, "id" => @online_group.id
    end
  end
  
  online_test "can upload up mirror files" do
    @offline_group.name = "ABC"; force_save_and_reload(@offline_group)
    mirror_data = gen_up_mirror_data(@offline_group)
    @offline_group.name = "XYZ"; force_save_and_reload(@offline_group)
    
    post :upload_up_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
    assert_response :success
    @offline_group.reload
    assert_equal "ABC", @offline_group.name
  end
  
  offline_test "can upload down mirror files" do
    global_record = GlobalRecord.new(:title => "123"); force_save_and_reload(global_record)
    mirror_data = gen_down_mirror_data(@offline_group)
    force_destroy(global_record)
    
    assert_equal 0, GlobalRecord.count
    post :upload_down_mirror, "id" => @offline_group.id, "mirror_data" => mirror_data
    assert_response :success
    assert_equal 1, GlobalRecord.count
    assert_equal "123", GlobalRecord.first.title
  end
    
  cross_test "can upload initial down mirror files" do
    mirror_data = ""
    in_online_app do
      get :download_down_mirror, "id" => @offline_group.id
      mirror_data = @response.binary_content
    end
    
    in_offline_app(false, true) do
      assert_equal 0, Group.count
      post :upload_initial_down_mirror, "mirror_data" => mirror_data
      assert_equal 1, Group.count
    end
  end
  
  offline_test "cannot retrieve down mirror files" do
    assert_raise OfflineMirror::PluginError do
      get :download_down_mirror, {"id" => @offline_group.id}
    end
  end
  
  offline_test "cannot upload up mirror files" do
    assert_raise OfflineMirror::PluginError do
      post :upload_up_mirror, "id" => @offline_group.id, "mirror_data" => gen_up_mirror_data(@offline_group)
    end
  end
  
  online_test "cannot upload down mirror files" do
    assert_raise OfflineMirror::PluginError do
      post :upload_down_mirror, "id" => @offline_group.id, "mirror_data" => gen_down_mirror_data(@offline_group)
    end
  end
  
  online_test "cannot upload a mirror file for an online group" do
    assert_raise OfflineMirror::PluginError do
      post :upload_up_mirror, "id" => @online_group.id, "mirror_data" => gen_up_mirror_data(@online_group)
    end
  end
end
