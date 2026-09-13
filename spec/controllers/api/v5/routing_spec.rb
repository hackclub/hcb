# frozen_string_literal: true

require "rails_helper"

# Every v5 route must reach a real action. A `resources ... only: [:create]`
# with no matching method is a 500 the first time a client calls it, and
# nothing else in the suite would catch a route added ahead of its action.
RSpec.describe "v5 routing", type: :request do
  it "maps every v5 route to a defined action" do
    v5_routes = Rails.application.routes.routes.select do |route|
      route.defaults[:controller].to_s.start_with?("api/v5/")
    end

    expect(v5_routes).not_to be_empty

    missing = v5_routes.filter_map do |route|
      controller = "#{route.defaults[:controller].camelize}Controller".constantize
      action = route.defaults[:action]

      "#{route.defaults[:controller]}##{action}" unless controller.action_methods.include?(action)
    end

    expect(missing).to be_empty, "routes with no matching action: #{missing.join(', ')}"
  end
end
