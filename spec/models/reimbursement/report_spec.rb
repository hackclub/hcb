# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  describe "validations" do
    context "when backed by a card grant" do
      # The card_grant factory's after_create :transfer_money callback runs
      # DisbursementService::Create, which requires a funded source event.
      # These specs only care about the card_grant FK, not real disbursement
      # mechanics, so we stub the callback the same way spec/models/card_grant_spec.rb does.
      before do
        allow_any_instance_of(CardGrant).to receive(:transfer_money)
      end

      it "rejects event_id changes" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:)

        report.event = destination_event

        expect(report.valid?(:update)).to be(false)
        expect(report.errors[:base]).to include(/card grant/i)
      end

      it "permits updates that do not change the event" do
        source_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:, name: "Old Name")

        report.name = "New Name"

        expect(report.valid?(:update)).to be(true)
      end
    end

    context "when not backed by a card grant" do
      it "permits event_id changes at the model layer" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        report = create(:reimbursement_report, user:, event: source_event)

        report.event = destination_event

        expect(report.valid?(:update)).to be(true)
      end
    end
  end
end
