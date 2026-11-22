require_relative "boot"

require "rails/all"


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Myverybox
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))
    config.active_storage.variant_processor = :mini_magick
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.generators.test_framework = :rspec

    # Mission Control (Solid Queue UI at /jobs): only for signed-in users. Its
    # controllers inherit ApplicationController (Devise's authenticate_user!)
    # and the route is wrapped in `authenticate :user`, so its own HTTP basic
    # auth is not needed.
    config.mission_control.jobs.base_controller_class = "ApplicationController"
    config.mission_control.jobs.http_basic_auth_enabled = false
    # always inspect Solid Queue (production's backend; its tables exist in every
    # environment), not whatever adapter development/tests happen to use
    config.mission_control.jobs.adapters = [:solid_queue]
  end
end
