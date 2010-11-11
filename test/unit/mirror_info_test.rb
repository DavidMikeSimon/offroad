require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MirrorInfoTest < Test::Unit::TestCase
  agnostic_test "can instantiate MirrorInfo instances, but they're invalid by default" do
    rec = nil
    assert_nothing_raised do
      rec = Offroad::MirrorInfo.new
    end
    assert_equal false, rec.valid?
  end
  
  double_test "can use new_from_group to create a MirrorInfo instance for a particular group" do
    rec = Offroad::MirrorInfo::new_from_group(@editable_group)
    assert rec.valid?
    assert Time.now - rec.created_at < 30
    assert_equal Offroad::online_url, rec.online_site
    assert_equal Offroad::app_name, rec.app
    assert rec.app_mode.downcase.include?( Offroad::app_online? ? "online" : "offline" )
    assert_equal Offroad::app_version, rec.app_version
    assert_equal RUBY_PLATFORM, rec.operating_system
    assert rec.generator.downcase.include?("offroad")
  end
  
  double_test "cannot save a MirrorInfo instance" do
    rec = Offroad::MirrorInfo::new_from_group(@editable_group)
    assert rec.valid?
    assert_raise Offroad::DataError do
      rec.save
    end
  end
end
