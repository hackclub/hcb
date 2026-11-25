# frozen_string_literal: true

require "rails_helper"

RSpec.describe Referral::Program, type: :model do
  let(:creator) { build_stubbed(:user) }

  it "accepts absolute HTTP(S) destinations and the blank root-path fallback" do
    [nil, "", " ", "https://example.com", "http://example.com:8080/path?ref=hcb#signup", "https://example.com/path/https://other.example"].each do |destination|
      program = described_class.new(name: "Referrals", creator:, redirect_to: destination)

      expect(program).to be_valid, "Expected #{destination.inspect} to be accepted: #{program.errors.full_messages}"
    end
  end

  it "rejects malformed, relative, and non-HTTP(S) destinations" do
    ["prefix/https://example.com", "https://example.com trailing text", "https://", "https:///path", "http:relative", "/relative", "//example.com", "javascript:https://example.com", "ftp://example.com"].each do |destination|
      program = described_class.new(name: "Referrals", creator:, redirect_to: destination)

      expect(program).not_to be_valid, "Expected #{destination.inspect} to be rejected"
      expect(program.errors[:redirect_to]).to include("is invalid")
    end
  end
end
