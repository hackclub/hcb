# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementService::Create do
  it "runs successfully" do
    freeze_time

    requestor = create(:user)
    source_event = create(:event, :with_positive_balance)
    create(:organizer_position, event: source_event, user: requestor)

    destination_event = create(:event)

    disbursement = described_class.new(
      name: "Boba Drops",
      amount: "123.45",
      requested_by_id: requestor.id,
      source_event_id: source_event.id,
      destination_event_id: destination_event.id,
    ).run

    expect(disbursement).to be_a(Disbursement)
    expect(disbursement).to be_reviewing
    expect(disbursement.name).to eq("Boba Drops")
    expect(disbursement.amount).to eq(123_45)
    expect(disbursement.requested_by).to eq(requestor)
    expect(disbursement.source_event).to eq(source_event)
    expect(disbursement.destination_event).to eq(destination_event)
    expect(disbursement.source_subledger).to be_nil
    expect(disbursement.destination_subledger).to be_nil
    expect(disbursement.scheduled_on).to be_nil
    expect(disbursement.should_charge_fee).to eq(false)
    expect(disbursement.source_transaction_category).to be_nil
    expect(disbursement.destination_transaction_category).to be_nil

    pending_outgoing = disbursement.raw_pending_outgoing_disbursement_transaction
    expect(pending_outgoing.amount_cents).to eq(-123_45)
    expect(pending_outgoing.date_posted).to eq(Date.today)

    cpt_outgoing = pending_outgoing.canonical_pending_transaction
    expect(cpt_outgoing.event).to eq(source_event)
    expect(cpt_outgoing.amount_cents).to eq(-123_45)
    expect(cpt_outgoing.memo).to eq("Outgoing transfer")
    expect(cpt_outgoing.custom_memo).to be_nil
    expect(cpt_outgoing.date).to eq(Date.today)
    expect(cpt_outgoing.fronted).to eq(false)
    expect(cpt_outgoing.hcb_code).to eq("HCB-500-#{disbursement.id}")
    expect(cpt_outgoing.category).to be_nil

    pending_incoming = disbursement.raw_pending_incoming_disbursement_transaction
    expect(pending_incoming.amount_cents).to eq(123_45)
    expect(pending_incoming.date_posted).to eq(Date.today)

    cpt_incoming = pending_incoming.canonical_pending_transaction
    expect(cpt_incoming.event).to eq(destination_event)
    expect(cpt_incoming.amount_cents).to eq(123_45)
    expect(cpt_incoming.memo).to eq("Incoming transfer")
    expect(cpt_incoming.custom_memo).to be_nil
    expect(cpt_incoming.date).to eq(Date.today)
    expect(cpt_incoming.fronted).to eq(false)
    expect(cpt_incoming.hcb_code).to eq("HCB-500-#{disbursement.id}")
    expect(cpt_incoming.category).to be_nil
  end

  it "auto-approves when requested by an admin" do
    requestor = create(:user, :make_admin)
    create(:governance_admin_transfer_limit, user: requestor)
    source_event = create(:event, :with_positive_balance)
    create(:organizer_position, event: source_event, user: requestor)

    destination_event = create(:event)

    disbursement = described_class.new(
      name: "Boba Drops",
      amount: "123.45",
      requested_by_id: requestor.id,
      source_event_id: source_event.id,
      destination_event_id: destination_event.id,
    ).run

    expect(disbursement).to be_a(Disbursement)
    expect(disbursement).to be_pending
    expect(disbursement.fulfilled_by).to eq(requestor)
  end

  it "skips the incoming transaction when scheduled" do
    freeze_time

    requestor = create(:user)
    source_event = create(:event, :with_positive_balance)
    create(:organizer_position, event: source_event, user: requestor)

    destination_event = create(:event)

    disbursement = described_class.new(
      name: "Boba Drops",
      amount: "123.45",
      requested_by_id: requestor.id,
      source_event_id: source_event.id,
      destination_event_id: destination_event.id,
      scheduled_on: Date.today + 7
    ).run

    expect(disbursement).to be_a(Disbursement)
    expect(disbursement.scheduled_on).to eq(Date.today + 7)

    expect(
      disbursement
        .raw_pending_outgoing_disbursement_transaction
        .canonical_pending_transaction
    ).to be_present

    expect(disbursement.raw_pending_incoming_disbursement_transaction).to be_nil
  end

  it "applies transaction categories when provided" do
    requestor = create(:user)
    source_event = create(:event, :with_positive_balance)
    create(:organizer_position, event: source_event, user: requestor)

    destination_event = create(:event)

    disbursement = described_class.new(
      name: "Boba Drops",
      amount: "123.45",
      requested_by_id: requestor.id,
      source_event_id: source_event.id,
      destination_event_id: destination_event.id,
      source_transaction_category_slug: "donations",
      destination_transaction_category_slug: "fundraising",
    ).run

    expect(disbursement).to be_a(Disbursement)
    expect(disbursement.source_transaction_category.slug).to eq("donations")
    expect(disbursement.destination_transaction_category.slug).to eq("fundraising")

    expect(
      disbursement
        .raw_pending_outgoing_disbursement_transaction
        .canonical_pending_transaction
        .category
        .slug
    ).to eq("donations")

    expect(
      disbursement
        .raw_pending_incoming_disbursement_transaction
        .canonical_pending_transaction
        .category
        .slug
    ).to eq("fundraising")
  end

end
