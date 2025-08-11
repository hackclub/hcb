# frozen_string_literal: true

ActiveSupport::Notifications.subscribe('deprecation.rails') do |_name, _start, _finish, _id, payload|
  message = payload[:message]
  callstack = payload[:callstack]
  deprecation_horizon = payload[:deprecation_horizon]
  gem_name = payload[:gem_name] || 'rails'

  # there doesn't seem to be a great way to get controller#action here without some more ceremony
  # so hopefully just the controller and stacktrace will be enough for us to narrow down any issues.
  class_name = "#{Thread.current[:public_activity_controller]&.class}"

  Appsignal.report_error(ActiveSupport::DeprecationException.new(message)) do
    Appsignal.set_namespace("deprecation.rails")
    Appsignal.set_action(class_name)
    Appsignal.add_tags(
      deprecation: true,
      gem: gem_name,
      horizon: deprecation_horizon
    )
    Appsignal.add_custom_data(
      deprecation_message: message,
      callstack: callstack
    )
  end
end