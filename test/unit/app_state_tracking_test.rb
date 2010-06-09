require File.dirname(__FILE__) + '/../test_helper'

class AppStateTrackingTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  online_test "creating global data causes creation of valid state data" do
    rec = GlobalRecord.create(:title => "Foo Bar")
  end
  
  online_test "saving global data updates mirror version only on changed records" do
  end
  
  offline_test "creating group data causes creation of valid state data" do
  end
  
  offline_test "saving group data updates mirror version only on changed records" do
  end
  
end

run_test_class AppStateTrackingTest
