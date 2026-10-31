# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursement, type: :model do
  # The group's ledger item is mapped to the Hack Club Bank event, which must exist.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  describe "grouping on create" do
    it "joins the group for the ISO week it was created in" do
      fee_reimbursement = travel_to(Time.utc(2026, 10, 14)) { create(:fee_reimbursement) }

      expect(fee_reimbursement.reload.fee_reimbursement_group.slug).to eq("2026_42")
    end

    it "reuses the week's existing group" do
      group = create(:fee_reimbursement_group, slug: Time.now.utc.strftime(FeeReimbursementGroup::SLUG_FORMAT))

      fee_reimbursement = nil
      expect { fee_reimbursement = create(:fee_reimbursement) }.not_to change(FeeReimbursementGroup, :count)

      expect(fee_reimbursement.reload.fee_reimbursement_group).to eq(group)
    end

    it "keeps a group it was given" do
      group = create(:fee_reimbursement_group, slug: "2026_42")

      fee_reimbursement = create(:fee_reimbursement, fee_reimbursement_group: group)

      expect(fee_reimbursement.reload.fee_reimbursement_group).to eq(group)
    end

    it "leaves a zero-amount fee reimbursement ungrouped" do
      fee_reimbursement = create(:fee_reimbursement, amount: 0)

      expect(fee_reimbursement.reload.fee_reimbursement_group).to be_nil
      expect(FeeReimbursementGroup.count).to eq(0)
    end
  end

  describe "once grouped or processed" do
    it "can't have its group changed" do
      fee_reimbursement = create(:fee_reimbursement).reload
      other_group = create(:fee_reimbursement_group, slug: "2020_01")

      expect(fee_reimbursement.update(fee_reimbursement_group: other_group)).to be(false)
      expect(fee_reimbursement.errors[:fee_reimbursement_group]).to include("can't be changed once set")
    end

    it "isn't grouped by the week it was created in once processed" do
      fee_reimbursement = create(:fee_reimbursement, processed_at: 1.day.ago)

      fee_reimbursement.assign_fee_reimbursement_group!

      expect(fee_reimbursement.reload.fee_reimbursement_group).to be_nil
      expect(FeeReimbursementGroup.count).to eq(0)
    end
  end
end
