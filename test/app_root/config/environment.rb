require File.join(File.dirname(__FILE__), 'boot')

RAILS_GEM_VERSION = '2.3.12'

Rails::Initializer.run do |config|
  config.cache_classes = false
  config.whiny_nils = true
  config.action_controller.session = {:key => 'rails_session', :secret => 'd229e4d22437432705ab3985d4d246'}

  if ENV['HOBO_TEST_MODE']
    puts "Loading Hobo gem"
    config.gem 'hobo'
    HOBO_TEST_MODE = true
  else
    HOBO_TEST_MODE = false
  end
  
  if ENV['PSQL_TEST_MODE']
    puts "Using postgresql for a test database"
    config.database_configuration_file = "#{RAILS_ROOT}/config/database-pg.yml"
  else
    puts "Using sqlite for a test database"
  end
end
