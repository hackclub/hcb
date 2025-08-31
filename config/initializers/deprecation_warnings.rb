# frozen_string_literal: true

ActiveSupport::Notifications.subscribe("deprecation.rails") do |_name, _start, _finish, _id, payload|
  message = payload[:message]
  callstack = payload[:callstack]
  deprecation_horizon = payload[:deprecation_horizon]
  gem_name = payload[:gem_name] || "rails"

  execution_context = ActiveSupport::ExecutionContext.to_h
  appsignal_action = (execution_context[:controller] || execution_context[:job]).class.to_s
  if execution_context[:controller]
    appsignal_action += "##{execution_context[:controller].action_name}"
  end

  Appsignal.report_error(ActiveSupport::DeprecationException.new(message)) do
    Appsignal.set_namespace("deprecation.rails")
    Appsignal.set_action(appsignal_action)
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
