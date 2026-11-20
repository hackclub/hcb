# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  # Not `travel_to(now) { ex.run }`: that sets ActiveSupport's nested-block
  # guard, which then trips when `attach_receipt` does its own
  # `travel_to(at) { ... }` to backdate a receipt upload.
  around do |ex|
    travel_to(now)
    ex.run
  ensure
    travel_back
  end

  describe ".receipt_overdue" do
    it "includes an unresolved charge whose receipt_due_at has passed" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(receipt_due_at: 1.day.ago)

      expect(Ledger::Item.receipt_overdue(now)).to include(charge)
    end

    it "excludes a charge whose receipt_due_at is in the future" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(receipt_due_at: 1.day.from_now)

      expect(Ledger::Item.receipt_overdue(now)).not_to include(charge)
    end

    it "excludes a charge with a receipt even if its receipt_due_at has passed" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 1.day.ago)
      charge.update!(receipt_due_at: 1.day.ago)

      expect(Ledger::Item.receipt_overdue(now)).not_to include(charge)
    end

    it "excludes a charge marked no/lost even if its receipt_due_at has passed" do
      charge = create_settled_card_charge(user:, settled_at: 5.days.ago)
      charge.update!(receipt_due_at: 1.day.ago, marked_no_or_lost_receipt_at: 1.day.ago)

      expect(Ledger::Item.receipt_overdue(now)).not_to include(charge)
    end
  end
end
