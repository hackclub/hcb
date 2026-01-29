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
    expect(pending_outgoing.date_posted).to eq(Date.current)

    cpt_outgoing = pending_outgoing.canonical_pending_transaction
    expect(cpt_outgoing.event).to eq(source_event)
    expect(cpt_outgoing.amount_cents).to eq(-123_45)
    expect(cpt_outgoing.memo).to eq("Outgoing transfer")
    expect(cpt_outgoing.custom_memo).to be_nil
    expect(cpt_outgoing.date).to eq(Date.current)
    expect(cpt_outgoing.fronted).to eq(false)
    expect(cpt_outgoing.hcb_code).to eq("HCB-500-#{disbursement.id}")
    expect(cpt_outgoing.category).to be_nil

    pending_incoming = disbursement.raw_pending_incoming_disbursement_transaction
    expect(pending_incoming.amount_cents).to eq(123_45)
    expect(pending_incoming.date_posted).to eq(Date.current)

    cpt_incoming = pending_incoming.canonical_pending_transaction
    expect(cpt_incoming.event).to eq(destination_event)
    expect(cpt_incoming.amount_cents).to eq(123_45)
    expect(cpt_incoming.memo).to eq("Incoming transfer")
    expect(cpt_incoming.custom_memo).to be_nil
    expect(cpt_incoming.date).to eq(Date.current)
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

  describe "subledger disbursements" do
    # Helper to fund a subledger with a positive balance
    def fund_subledger(subledger, amount_cents:)
      ct = create(:canonical_transaction, amount_cents: amount_cents)
      create(:canonical_event_mapping, canonical_transaction: ct, event: subledger.event, subledger: subledger)
    end

    it "creates disbursement with source_subledger" do
      freeze_time

      requestor = create(:user)
      source_event = create(:event)
      source_subledger = create(:subledger, event: source_event)
      fund_subledger(source_subledger, amount_cents: 10000)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      disbursement = described_class.new(
        name: "Subledger Transfer",
        amount: "50.00",
        requested_by_id: requestor.id,
        source_event_id: source_event.id,
        destination_event_id: destination_event.id,
        source_subledger_id: source_subledger.id,
      ).run

      expect(disbursement).to be_a(Disbursement)
      expect(disbursement.source_subledger).to eq(source_subledger)
      expect(disbursement.destination_subledger).to be_nil
    end

    it "creates disbursement with destination_subledger" do
      freeze_time

      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)
      destination_subledger = create(:subledger, event: destination_event)

      disbursement = described_class.new(
        name: "Subledger Transfer",
        amount: "50.00",
        requested_by_id: requestor.id,
        source_event_id: source_event.id,
        destination_event_id: destination_event.id,
        destination_subledger_id: destination_subledger.id,
      ).run

      expect(disbursement).to be_a(Disbursement)
      expect(disbursement.source_subledger).to be_nil
      expect(disbursement.destination_subledger).to eq(destination_subledger)
    end

    it "allows same event with different subledgers (subledger transfer)" do
      freeze_time

      requestor = create(:user)
      event = create(:event)
      source_subledger = create(:subledger, event: event)
      destination_subledger = create(:subledger, event: event)
      fund_subledger(source_subledger, amount_cents: 10000)
      create(:organizer_position, event: event, user: requestor)

      disbursement = described_class.new(
        name: "Subledger to Subledger",
        amount: "25.00",
        requested_by_id: requestor.id,
        source_event_id: event.id,
        destination_event_id: event.id,
        source_subledger_id: source_subledger.id,
        destination_subledger_id: destination_subledger.id,
      ).run

      expect(disbursement).to be_a(Disbursement)
      expect(disbursement.source_event).to eq(event)
      expect(disbursement.destination_event).to eq(event)
      expect(disbursement.source_subledger).to eq(source_subledger)
      expect(disbursement.destination_subledger).to eq(destination_subledger)
    end

    it "auto-approves same-event subledger transfers" do
      freeze_time

      requestor = create(:user)
      event = create(:event)
      source_subledger = create(:subledger, event: event)
      destination_subledger = create(:subledger, event: event)
      fund_subledger(source_subledger, amount_cents: 10000)
      create(:organizer_position, event: event, user: requestor)

      disbursement = described_class.new(
        name: "Auto-approved Subledger Transfer",
        amount: "25.00",
        requested_by_id: requestor.id,
        source_event_id: event.id,
        destination_event_id: event.id,
        source_subledger_id: source_subledger.id,
        destination_subledger_id: destination_subledger.id,
      ).run

      expect(disbursement).to be_pending
    end
  end

  describe "edge cases" do
    it "raises error for demo destination event" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      demo_event = create(:event, :demo_mode)

      expect {
        described_class.new(
          name: "Demo Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: demo_event.id,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /cannot be a demo event/)
    end

    it "raises error for demo source event" do
      requestor = create(:user)
      demo_event = create(:event, :demo_mode, :with_positive_balance)
      create(:organizer_position, event: demo_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Demo Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: demo_event.id,
          destination_event_id: destination_event.id,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /cannot be a demo event/)
    end

    it "raises error for frozen source event" do
      requestor = create(:user)
      frozen_event = create(:event, :with_positive_balance)
      frozen_event.update!(financially_frozen: true)
      create(:organizer_position, event: frozen_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Frozen Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: frozen_event.id,
          destination_event_id: destination_event.id,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /is currently frozen/)
    end

    it "raises error for scheduled date in the past" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Past Scheduled Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: destination_event.id,
          scheduled_on: 1.day.ago.to_date,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /must be in the future/)
    end

    it "raises error for scheduled date today" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Today Scheduled Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: destination_event.id,
          scheduled_on: Date.today,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /must be in the future/)
    end

    it "allows scheduled date in the future" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)
      future_date = 1.week.from_now.to_date

      disbursement = described_class.new(
        name: "Future Scheduled Transfer",
        amount: "100.00",
        requested_by_id: requestor.id,
        source_event_id: source_event.id,
        destination_event_id: destination_event.id,
        scheduled_on: future_date,
      ).run

      expect(disbursement).to be_a(Disbursement)
      expect(disbursement.scheduled_on).to eq(future_date)
    end

    it "raises error for same source and destination event without subledgers" do
      requestor = create(:user)
      event = create(:event, :with_positive_balance)
      create(:organizer_position, event: event, user: requestor)

      expect {
        described_class.new(
          name: "Same Event Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: event.id,
          destination_event_id: event.id,
        ).run
      }.to raise_error(ActiveRecord::RecordInvalid, /must be different than source event/)
    end

    it "raises error for insufficient funds" do
      requestor = create(:user)
      source_event = create(:event) # No positive balance
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "No Funds Transfer",
          amount: "100.00",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: destination_event.id,
        ).run
      }.to raise_error(DisbursementService::Create::UserError, /don't have enough money/)
    end

    it "raises error for zero amount" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Zero Amount Transfer",
          amount: "0",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: destination_event.id,
        ).run
      }.to raise_error(ArgumentError, /must be greater than 0/)
    end

    it "raises error for negative amount" do
      requestor = create(:user)
      source_event = create(:event, :with_positive_balance)
      create(:organizer_position, event: source_event, user: requestor)

      destination_event = create(:event)

      expect {
        described_class.new(
          name: "Negative Amount Transfer",
          amount: "-50.00",
          requested_by_id: requestor.id,
          source_event_id: source_event.id,
          destination_event_id: destination_event.id,
        ).run
      }.to raise_error(ArgumentError, /must be greater than 0/)
    end
  end

end
