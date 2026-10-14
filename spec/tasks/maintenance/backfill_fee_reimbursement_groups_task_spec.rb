# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillFeeReimbursementGroupsTask do
  # The group's ledger item is mapped to the Hack Club Bank event; NOEVENT is
  # where the mapper's Stripe top-up memo rule puts an item with no group yet.
  # Both must exist.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
  let!(:noevent) { create(:event, id: EventMappingEngine::EventIds::NOEVENT) }

  def run_task
    task = described_class.new
    task.collection.find_each { |record| task.process(record) }
  end

  def topup
    StripeTopup.create!(amount_cents: 1_23, description: "Fee reimbursement", statement_descriptor: "HCB-XXXXX", stripe_id: "tu_#{SecureRandom.hex(4)}")
  end

  it "creates the group for a pre-existing weekly code, links its ledger item and attaches that week's top-ups" do
    hcb_code = HcbCode.create!(hcb_code: "HCB-900-2026_42")
    ct = create(:canonical_transaction, memo: "STRIPE Stripe Top HCB-#{hcb_code.short_code}", amount_cents: -1_23)
    item = ct.reload.ledger_item
    expect(item.linked_object).to be_nil

    in_week = create(:fee_reimbursement, processed_at: Time.utc(2026, 10, 14, 3), stripe_topup: topup)
    zero_amount = create(:fee_reimbursement, amount: 0, processed_at: Time.utc(2026, 10, 14, 3))
    other_week = create(:fee_reimbursement, processed_at: Time.utc(2026, 10, 7, 3), stripe_topup: topup)
    unprocessed = create(:fee_reimbursement)

    expect { run_task }.to change(FeeReimbursementGroup, :count).by(1)

    group = FeeReimbursementGroup.find_by!(week: "2026_42")
    expect(group.ledger_item).to eq(item)
    expect(Ledger::Item.where(short_code: hcb_code.short_code).count).to eq(1)

    item.reload
    expect(item.linked_object).to eq(group)
    expect(item.memo).to eq(group.memo)
    expect(item.primary_ledger).to eq(hack_club_bank.ledger)

    expect(in_week.reload.fee_reimbursement_group).to eq(group)
    expect(zero_amount.reload.fee_reimbursement_group).to be_nil
    expect(other_week.reload.fee_reimbursement_group).to be_nil
    expect(unprocessed.reload.fee_reimbursement_group).to be_nil
  end

  it "is idempotent and leaves groups that already exist alone" do
    group = create(:fee_reimbursement_group, week: "2026_42")
    item = group.ledger_item
    fee_reimbursement = create(:fee_reimbursement, processed_at: Time.utc(2026, 10, 14, 3), stripe_topup: topup, fee_reimbursement_group: group)

    expect { run_task }.not_to change(FeeReimbursementGroup, :count)
    expect { run_task }.not_to change(Ledger::Item, :count)

    expect(group.reload.ledger_item).to eq(item)
    expect(fee_reimbursement.reload.fee_reimbursement_group).to eq(group)
  end

  it "ignores codes that aren't keyed on a week" do
    HcbCode.create!(hcb_code: "HCB-900-garbage")

    expect { run_task }.not_to change(FeeReimbursementGroup, :count)
  end
end
