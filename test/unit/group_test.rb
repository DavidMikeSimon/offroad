require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < ActiveSupport::TestCase
	common_test :groups_have_expected_offline_statuses do
		puts "[GT] ADLP IS NOW " + ActiveSupport::Dependencies.load_paths.join(",")
		assert Group.find_by_name("An Online Group").group_online?, "Online group should respond true to group_online?"
		assert Group.find_by_name("An Offline Group").group_offline?, "Offline group should repond true to group_offline?"
	end
end
