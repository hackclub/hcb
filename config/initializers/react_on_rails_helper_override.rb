# frozen_string_literal: true

# React on Rails ships a global `react_component` helper that collides with the
# legacy react-rails helper while this app is migrated incrementally.
module LegacyReactRailsHelperOverride
  def react_component(*args, &block)
    React::Rails::ViewHelper.instance_method(:react_component).bind(self).call(*args, &block)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(ReactOnRailsHelper)

  ReactOnRailsHelper.prepend(LegacyReactRailsHelperOverride) unless ReactOnRailsHelper < LegacyReactRailsHelperOverride
end
