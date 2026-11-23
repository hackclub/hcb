# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPositionDeletionRequest do
  describe "#organizer_missing_receipts" do
    include_context "card locking charges"

    it "lists the organizer's card charges missing a receipt in the request's event only" do
      organizer_position = create(:organizer_position, user:, event:)
      other_event = create(:event, plan_type: Event::Plan::Standard)
      in_event = create_settled_card_charge(user:, settled_at: 2.days.ago)
      create_settled_card_charge(user:, settled_at: 1.day.ago, charge_event: other_event)
      create_settled_card_charge(user:, settled_at: 3.days.ago, uploaded_at: 2.days.ago)
      request = described_class.new(organizer_position:, submitted_by: user, reason: "Leaving")

      expect(request.organizer_missing_receipts).to contain_exactly(in_event)
    end
  end
end
