require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.cache_classes = false
  config.whiny_nils = true
  config.action_controller.session = {:key => 'rails_session', :secret => 'd229e4d22437432705ab3985d4d246'}
end
