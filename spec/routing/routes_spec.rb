# frozen_string_literal: true

require "rails_helper"
require "rails/commands/unused_routes/unused_routes_command"

RSpec.describe "Routes" do
  let(:all_routes) { Rails.application.routes.routes }

  # Shadowed routes we're leaving alone. Don't add to this; move the new route
  # above the one that catches it instead.
  let(:known_shadowed) do
    [
      # `resources :events, path: "/"` puts its index at /, which root serves.
      # The events index is at /events instead.
      "GET / goes to static_pages#index, not events#index",
      # The member route `get "/"` in `resources :logins` matches /logins/:id
      # first. The login page is at /users/auth instead.
      "GET /logins/new goes to logins#choose_login_preference, not logins#new",
    ]
  end

  it "only routes to controller actions that exist" do
    # Same check as `bin/rails routes --unused`: the controller is missing, or
    # the action has neither a method nor a template.
    unused = all_routes
             .select { |route| Rails::Command::UnusedRoutesCommand::RouteInfo.new(route).unused? }
             .map { |route| "#{route.verb} #{route.path.spec} → #{route.requirements[:controller]}##{route.requirements[:action]}" }

    expect(unused).to be_empty, "These routes point at controller actions that don't exist. Remove them, or add the action:\n#{unused.join("\n")}"
  end

  it "doesn't define routes that an earlier route catches first" do
    shadowed = all_routes.flat_map do |route|
      controller, action = route.requirements.values_at(:controller, :action)
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      # Only a fixed path can be recognized as-is, and routes into gems' controllers aren't ours to order.
      next [] if controller.nil? || path.match?(/[:*(]/) || !Rails.root.join("app/controllers", "#{controller}_controller.rb").exist?

      route.verb.split("|").filter_map do |verb|
        found = Rails.application.routes.recognize_path(path, method: verb)
        next if found.values_at(:controller, :action) == [controller, action]

        "#{verb} #{path} goes to #{found[:controller]}##{found[:action]}, not #{controller}##{action}"
      rescue ActionController::RoutingError
        nil # e.g. behind a constraint that a bare request doesn't pass
      end
    end
    new_shadowed = shadowed - known_shadowed

    expect(new_shadowed).to be_empty, "An earlier route matches these first, so they're never reached. Move each one above the route that catches it:\n#{new_shadowed.join("\n")}"
  end
end
