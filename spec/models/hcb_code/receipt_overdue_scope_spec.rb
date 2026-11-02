# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  around { |ex| travel_to(now) { ex.run } }

  describe ".receipt_overdue" do
    it "includes an unresolved charge whose receipt_due_at has passed" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hcb_code.update!(receipt_due_at: 1.day.ago)

      expect(HcbCode.receipt_overdue(now)).to include(hcb_code)
    end

    it "excludes a charge whose receipt_due_at is in the future" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hcb_code.update!(receipt_due_at: 1.day.from_now)

      expect(HcbCode.receipt_overdue(now)).not_to include(hcb_code)
    end

    it "excludes a resolved charge even if its receipt_due_at has passed" do
      hcb_code = create_settled_card_charge(user:, settled_at: 5.days.ago)
      hcb_code.update!(receipt_due_at: 1.day.ago, receipt_resolved_at: 1.day.ago)

      expect(HcbCode.receipt_overdue(now)).not_to include(hcb_code)
    end
  end
end
