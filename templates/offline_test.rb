# This file defines envrionment used for testing the offline mode implemented by the offroad plugin
# You can define tests specifically for this environment by following the pattern set in the plugin's Rakefile
# In the regular "test" environment, the plugin considers itself to be in the online mode

# Use the offline test database configuration file instead of the regular one
config.database_configuration_file = "config/offline_test_database.yml"

config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false
config.action_view.cache_template_loading            = true

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection    = false

# Tell Action Mailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test
