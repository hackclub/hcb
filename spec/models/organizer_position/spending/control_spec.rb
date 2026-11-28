# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizerPosition::Spending::Control do
  let(:position) { create(:organizer_position, role: :member) }
  let(:start) { 2.days.ago.change(usec: 0) }
  let(:finish) { 1.day.ago.change(usec: 0) }
  let(:control) { position.spending_controls.create!(active: false, created_at: start, ended_at: finish) }
  let(:cardholder) { create(:stripe_cardholder, user: position.user) }
  let(:card) { create(:stripe_card, :with_stripe_id, event: position.event, stripe_cardholder: cardholder) }

  def card_item(amount_cents, datetime:, card: self.card, **attributes)
    charge = CardCharge.create!(stripe_card: card)
    item = create(:ledger_item, linked_object: charge)
    # Seed materialized ledger state independently of the Stripe import pipeline.
    item.update_columns(amount_cents:, datetime:, **attributes)
    item
  end

  it "nets pending charges, captures, and refunds on the member's main-ledger cards" do
    control.allowances.create!(amount_cents: 50_00, authorized_by: position.user)
    pending = card_item(-11_00, datetime: start, pending_at: start, status: "pending")
    captured = card_item(-17_50, datetime: finish + 1.hour, pending_at: finish, status: "settled", ct_count: 1)
    refund = card_item(3_25, datetime: finish, status: "settled", ct_count: 1)
    card_item(0, datetime: finish, status: "declined")
    card_item(0, datetime: finish, status: "released")
    card_item(-8_00, datetime: start, pending_at: start - 1.second)
    card_item(-9_00, datetime: finish + 1.second)
    card_item(-12_00, datetime: start, card: create(:stripe_card, :with_stripe_id, event: position.event))
    card_item(-13_00, datetime: start, card: create(:stripe_card, :with_stripe_id, stripe_cardholder: cardholder))
    grant_card = create(:stripe_card, :with_stripe_id, event: position.event, stripe_cardholder: cardholder, subledger: create(:subledger, event: position.event))
    card_item(-14_00, datetime: start, card: grant_card)

    expect(control.transactions).to contain_exactly(pending, captured, refund)
    expect(control.total_spent_cents).to eq(25_25)
    expect(control.balance_cents).to eq(24_75)
  end

  it "only warns about a drop across $25 when the charge belongs to the control" do
    control.allowances.create!(amount_cents: 50_00, authorized_by: position.user)
    in_period = card_item(-25_00, datetime: finish)
    too_late = card_item(-1_00, datetime: finish + 1.second)

    expect do
      SpendingControlService.check_low_balance(control, ledger_item_id: too_late.id, balance_change_cents: -1_00)
    end.not_to have_enqueued_mail(OrganizerPosition::Spending::ControlsMailer, :low_balance_warning)

    expect do
      SpendingControlService.check_low_balance(control, ledger_item_id: in_period.id, balance_change_cents: -1_00)
    end.to have_enqueued_mail(OrganizerPosition::Spending::ControlsMailer, :low_balance_warning)
  end
end
