# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Balance::ObserverMailer, type: :mailer do
  describe "#low_balance" do
    it "tells the observing user the new balance and their threshold" do
      event = create(:event, name: "Daydream")
      user = create(:user, full_name: "Orpheus Dinosaur", email: "orpheus@example.com")
      observer = create(:ledger_balance_observer, ledger: event.ledger, user:, amount_cents: 50_00)

      mail = described_class.with(observer:, balance_cents: 12_34).low_balance

      expect(mail.to).to eq(["orpheus@example.com"])
      expect(mail.subject).to eq("Daydream's balance has dropped below $50.00")
      expect(mail.body.encoded).to include("$12.34").and include("$50.00").and include(edit_event_url(event, tab: "details"))
    end
  end
end
