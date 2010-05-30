require File.dirname(__FILE__) + '/../test_helper'

class GroupsControllerTest < ActionController::TestCase
	online_test :generate_down_mirror_file do
		puts "ONLINE TEST"
		assert true
	end

	offline_test :generate_up_mirror_file do
		puts "OFFLINE TEST"
		assert true
	end
end

run_test_class GroupsControllerTest
