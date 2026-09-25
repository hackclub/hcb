# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::FormPolicy, type: :policy do
  # Hashids are guessable, so an unclaimed form's page has to be refused, not crash.
  it "refuses everyone an unclaimed form, even admins and auditors" do
    form = Tax::Form.create!(aasm_state: :unclaimed, external_service: :manual, import_email: "orpheus@hackclub.com")

    [create(:user, email: "orpheus@hackclub.com"), create(:user, access_level: :auditor), create(:user, access_level: :admin)].each do |user|
      policy = described_class.new(user, form)
      expect([policy.show?, policy.completed?, policy.discard?, policy.create_legal_entity?]).to all(be false)
    end
  end
end
