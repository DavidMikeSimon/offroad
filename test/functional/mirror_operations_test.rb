require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MirrorOperationsTest < ActionController::TestCase
  tests GroupController
  
  cross_test "can create an offline app then use it to work with the online app" do
    mirror_data = ""
    in_online_app do
      test_group = Group.create(:name => "Test Group")
      
      GlobalRecord.create(:title => "Important Announcement", :some_boolean => true)
      GlobalRecord.create(:title => "Trivial Announcement", :some_boolean => true)
      
      GroupOwnedRecord.create(:description => "First Item", :group => test_group)
      GroupOwnedRecord.create(:description => "Second Item", :group => test_group)
      GroupOwnedRecord.create(:description => "Third Item", :group => test_group)
      
      test_group.group_offline = true
      get :download_down_mirror, "id" => test_group.id
      mirror_data = @response.binary_content
    end
    
    in_offline_app(false, true) do
      assert_equal 0, Group.count
      assert_equal 0, GlobalRecord.count
      assert_equal 0, GroupOwnedRecord.count
      post :upload_initial_down_mirror, "mirror_data" => mirror_data
      assert_equal 1, Group.count
      assert_equal 2, GlobalRecord.count
      assert_equal 3, GroupOwnedRecord.count
      
      group = Group.first
      group.name = "Renamed Group"
      group.save!
      
      first_item = GroupOwnedRecord.find_by_description("First Item")
      first_item.description = "Absolutely The First Item"
      first_item.save!
      
      second_item = GroupOwnedRecord.find_by_description("Second Item")
      second_item.destroy
      
      get :download_up_mirror, "id" => group.id
      mirror_data = @response.binary_content
    end
    
    in_online_app do
      post :upload_up_mirror, "id" => Group.find_by_name("Test Group").id, "mirror_data" => mirror_data
      
      assert_nil Group.find_by_name("Test Group")
      assert_not_nil Group.find_by_name("Renamed Group")
      
      assert_nil GroupOwnedRecord.find_by_description("First Item")
      assert_not_nil GroupOwnedRecord.find_by_description("Absolutely The First Item")
      assert_nil GroupOwnedRecord.find_by_description("Second Item")
      assert_not_nil GroupOwnedRecord.find_by_description("Third Item")
    end
  end
end
