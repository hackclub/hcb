# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ahoy cookies", type: :request do
  # Flagged by the PCI scan: nothing in the browser needs to read these.
  it "are HttpOnly" do
    get auth_users_path

    set_cookie = Array(response.headers["set-cookie"]).join("\n")
    %w[ahoy_visitor ahoy_visit].each do |name|
      expect(set_cookie).to match(/^#{name}=[^\n]*;\s*httponly/i), "#{name} is missing HttpOnly"
    end
  end
end
