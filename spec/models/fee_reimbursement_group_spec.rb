# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursementGroup, type: :model do
  # The group's ledger item is mapped to the Hack Club Bank event. NOEVENT is
  # where the mapper's Stripe top-up memo rule (meant for Issuing balance
  # top-ups) puts a top-up it can't attribute, which only happens to an item
  # with no group yet; both must exist.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
  let!(:noevent) { create(:event, id: EventMappingEngine::EventIds::NOEVENT) }

  it "is keyed on the ISO week" do
    group = create(:fee_reimbursement_group, slug: "2026_42")

    expect(group.hcb_code).to eq("HCB-900-2026_42")
    expect(group.local_hcb_code.hcb_code).to eq("HCB-900-2026_42")
    expect(group.start_date).to eq(Date.new(2026, 10, 12))
    expect(group.memo).to eq("🗂️ Stripe fee reimbursements for week of 10/12")
    expect(group.event).to eq(hack_club_bank)
  end

  it "requires a unique, well-formed week" do
    create(:fee_reimbursement_group, slug: "2026_42")

    expect(build(:fee_reimbursement_group, slug: "2026_42")).not_to be_valid
    expect(build(:fee_reimbursement_group, slug: "2026-42")).not_to be_valid
    expect(build(:fee_reimbursement_group, slug: nil)).not_to be_valid
  end

  describe "ledger item" do
    it "eagerly creates an intended ledger item on create" do
      group = create(:fee_reimbursement_group, slug: "2026_42")

      item = group.ledger_item
      expect(item).to be_present
      expect(item.linked_object).to eq(group)
      expect(item.status).to eq("intended")
      expect(item.amount_cents).to eq(0)
      expect(item.intended_at).to be_within(1.second).of(group.created_at)
      expect(item.memo).to eq(group.memo)
      expect(item.humanized_type).to eq("Stripe fee reimbursements")
      # Found by this short code when the top-ups' bank debits come in.
      expect(item.short_code).to eq(group.local_hcb_code.short_code)
      expect(group.local_hcb_code.ledger_item).to eq(item)
      # Mapped to Hack Club Bank's ledger via the linked object, before any transaction.
      expect(item.primary_ledger).to eq(hack_club_bank.ledger)
    end

    it "settles onto the intended item when a top-up's bank debit with its short code comes in" do
      group = create(:fee_reimbursement_group, slug: "2026_42")
      item = group.ledger_item

      first = create(:canonical_transaction, memo: "STRIPE Stripe Top HCB-#{group.local_hcb_code.short_code}", amount_cents: -1_23)
      second = create(:canonical_transaction, memo: "STRIPE Stripe Top HCB-#{group.local_hcb_code.short_code}", amount_cents: -4_56)

      expect(first.reload.ledger_item).to eq(item)
      expect(second.reload.ledger_item).to eq(item)
      expect(Ledger::Item.where(short_code: group.local_hcb_code.short_code).count).to eq(1)

      item.reload
      expect(item.status).to eq("settled")
      expect(item.amount_cents).to eq(-5_79)
      expect(item.intended_at).to be_nil
      expect(item.receipt_required).to be(false)
      expect(item.memo).to eq(group.memo)
      # Fee reimbursements are Hack Club Bank's; the Issuing top-up memo rule doesn't apply.
      expect(item.primary_ledger).to eq(hack_club_bank.ledger)
    end

    it "links the week's existing ledger item instead of creating a second one" do
      hcb_code = HcbCode.create!(hcb_code: "HCB-900-2026_42")
      ct = create(:canonical_transaction, memo: "STRIPE Stripe Top HCB-#{hcb_code.short_code}", amount_cents: -1_23)
      existing = ct.reload.ledger_item
      expect(existing.linked_object).to be_nil
      expect(existing.primary_ledger).to eq(noevent.ledger)

      group = create(:fee_reimbursement_group, slug: "2026_42")

      expect(group.ledger_item).to eq(existing)
      expect(Ledger::Item.where(short_code: hcb_code.short_code).count).to eq(1)

      existing.reload
      expect(existing.linked_object).to eq(group)
      expect(existing.status).to eq("settled")
      expect(existing.amount_cents).to eq(-1_23)
      expect(existing.memo).to eq(group.memo)
      expect(existing.primary_ledger).to eq(hack_club_bank.ledger)
    end

    it "does not take over an item linked to something else" do
      hcb_code = HcbCode.create!(hcb_code: "HCB-900-2026_42")
      fee_revenue = create(:fee_revenue)
      other = create(:ledger_item, short_code: hcb_code.short_code, linked_object: fee_revenue)

      group = create(:fee_reimbursement_group, slug: "2026_42")

      expect(group.ledger_item).to be_nil
      expect(other.reload.linked_object).to eq(fee_revenue)
    end
  end
end
