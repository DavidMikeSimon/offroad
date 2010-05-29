require File.dirname(__FILE__) + '/../test_helper'

class GroupsControllerTest < ActionController::TestCase
	online_test :generate_down_mirror_file do
		puts "ONLINE GDMF"
		assert true
	end

	offline_test :generate_up_mirror_file do
		puts "OFFLINE GUMF"
		assert true
	end

	common_test :generate_mirror_file do
		puts "COMMON GMF"
		assert true
	end
end
