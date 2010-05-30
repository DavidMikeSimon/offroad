require File.dirname(__FILE__) + '/../test_helper'

class GroupsControllerTest < ActionController::TestCase
	online_test :generate_down_mirror_file do
		assert true
	end

	offline_test :generate_up_mirror_file do
		assert true
	end
end
