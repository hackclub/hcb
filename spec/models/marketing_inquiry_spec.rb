# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketingInquiry do
  def build_inquiry(**attrs)
    described_class.new(page: "ai_safety", email: "ada@example.org", **attrs)
  end

  it "is valid with a page and an email" do
    expect(build_inquiry).to be_valid
  end

  it "only accepts known pages and audiences" do
    expect(build_inquiry(page: "funders")).not_to be_valid
    expect(build_inquiry(audience: "admin")).not_to be_valid
    expect(build_inquiry(audience: "funder")).to be_valid
  end

  it "checks the email format and length" do
    expect(build_inquiry(email: "nope")).not_to be_valid
    expect(build_inquiry(email: "#{"a" * 250}@b.co")).not_to be_valid
  end

  it "caps name and message lengths" do
    expect(build_inquiry(name: "a" * 201)).not_to be_valid
    expect(build_inquiry(message: "a" * 5_001)).not_to be_valid
  end

  it "only accepts a lowercase slug ref" do
    expect(build_inquiry(ref: "newsletter_1")).to be_valid
    expect(build_inquiry(ref: "Newsletter")).not_to be_valid
    expect(build_inquiry(ref: "a" * 65)).not_to be_valid
  end
end
