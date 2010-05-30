require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < ActiveSupport::TestCase
	common_test :groups_have_expected_offline_statuses do
		assert Group.find_by_name("An Online Group").group_online?, "Online group should respond true to group_online?"
		assert Group.find_by_name("An Offline Group").group_offline?, "Offline group should respond true to group_offline?"
	end
end

run_test_class GroupTest
