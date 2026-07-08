# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doorkeeper::Application::ResourceGrantTemplate do
  let(:application) { Doorkeeper::Application.create!(name: "Test App", redirect_uri: "https://example.com/callback", scopes: "restricted") }

  it "is valid with a scope root" do
    template = described_class.new(application:, resource_type: "comments", access_level: "read", scope_root_type: "Event", scope_root_id: 1)
    expect(template).to be_valid
  end

  it "is valid with no scope root (whole resource type)" do
    template = described_class.new(application:, resource_type: "comments", access_level: "read")
    expect(template).to be_valid
  end

  it "is invalid when scope_root_type is set without scope_root_id" do
    template = described_class.new(application:, resource_type: "comments", access_level: "read", scope_root_type: "Event")
    expect(template).not_to be_valid
  end

  it "is destroyed when its application is destroyed" do
    template = application.resource_grant_templates.create!(resource_type: "comments", access_level: "read")
    application.destroy!
    expect(described_class.exists?(template.id)).to be(false)
  end
end
