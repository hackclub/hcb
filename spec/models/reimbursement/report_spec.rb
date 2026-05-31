# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  describe "#minimum_wire_amount_cents" do
    context "without a card grant" do
      it "returns the event minimum" do
        event = create(:event)
        report = create(:reimbursement_report, event: event)
        expect(report.minimum_wire_amount_cents).to eq(event.minimum_wire_amount_cents)
      end

      it "returns 100 when event is exempt from wire minimum" do
        event = create(:event)
        Flipper.enable(:exempt_from_wire_minimum, event)
        report = create(:reimbursement_report, event: event)
        expect(report.minimum_wire_amount_cents).to eq(100)
      end
    end

    context "with a card grant" do
      it "still respects the event wire minimum exemption" do
        event = create(:event)
        Flipper.enable(:exempt_from_wire_minimum, event)
        report = create(:reimbursement_report, event: event)
        allow(report).to receive(:card_grant).and_return(instance_double(CardGrant))
        expect(report.minimum_wire_amount_cents).to eq(100)
      end

      it "returns $500 when event is not exempt" do
        event = create(:event)
        report = create(:reimbursement_report, event: event)
        allow(report).to receive(:card_grant).and_return(instance_double(CardGrant))
        expect(report.minimum_wire_amount_cents).to eq(500_00)
      end
    end
  end
end
