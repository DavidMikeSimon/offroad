require File.dirname(__FILE__) + '/../test_helper'

class MirrorInfoTest < ActiveSupport::TestCase
  def setup
    create_testing_system_state_and_groups
  end
  
  common_test "can instantiate MirrorInfo instances, but they're invalid by default" do
    rec = nil
    assert_nothing_raised do
      rec = OfflineMirror::MirrorInfo.new
    end
    assert_equal false, rec.valid?
  end
  
  common_test "can use new_from_group to create a MirrorInfo instance for a particular group" do
    rec = OfflineMirror::MirrorInfo::new_from_group(@editable_group)
    assert rec.valid?
    assert Time.now - rec.created_at < 30
    assert_equal OfflineMirror::online_url, rec.online_site
    assert_equal OfflineMirror::app_name, rec.app
    assert rec.app_mode.downcase.include?( OfflineMirror::app_online? ? "online" : "offline" )
    assert_equal OfflineMirror::app_version, rec.app_version
    assert_equal RUBY_PLATFORM, rec.operating_system
    assert rec.generator.downcase.include?("offline mirror")
  end
  
  common_test "cannot save a MirrorInfo instance" do
    rec = OfflineMirror::MirrorInfo::new_from_group(@editable_group)
    assert rec.valid?
    assert_raise RuntimeError do
      rec.save
    end
  end
  
end

run_test_class MirrorInfoTest