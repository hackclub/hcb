# frozen_string_literal: true

require "rails_helper"

RSpec.describe "card-locking settle hooks" do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  it "enqueues the materialize job when the old-engine mapping settles a card charge" do
    # Both engines fire for a settled Stripe charge (the CanonicalEventMapping
    # hook plus the auto-created Ledger::Mapping's commit hooks); the job is
    # idempotent, so the exact count is an implementation detail.
    expect { create_settled_card_charge(user:, settled_at: 1.day.ago) }
      .to have_enqueued_job(CardLocking::MaterializeChargeJob).at_least(:once)
  end

  it "enqueues the materialize job when a new-engine primary mapping settles a card charge" do
    stripe_cardholder = create(:stripe_cardholder, user:)
    stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:, event:)
    raw_stripe_transaction = create(
      :raw_stripe_transaction, stripe_card:, stripe_authorization_id: SecureRandom.hex(8),
      created_at: 1.day.ago, updated_at: 1.day.ago, date_posted: 1.day.ago.to_date
    )
    # Work around a raw_stripe_transaction factory quirk: it stores the
    # cardholder's AR id rather than its stripe_id, so stripe_cardholder
    # lookups by stripe_id (used by Ledger::Item#stripe_cardholder) fail.
    raw_stripe_transaction.update!(
      stripe_transaction: raw_stripe_transaction.stripe_transaction.merge("cardholder" => stripe_cardholder.stripe_id)
    )

    # Creating the canonical transaction lets Ledger::Mapper resolve the event
    # through the Stripe card and auto-create the primary Ledger::Mapping,
    # whose commit hook enqueues the job. No CanonicalEventMapping exists here,
    # so the old-engine hook can't be the source.
    canonical_transaction = nil
    expect do
      canonical_transaction = create(
        :canonical_transaction, amount_cents: -10_00, memo: "Test Merchant", date: 1.day.ago.to_date,
        created_at: 1.day.ago, updated_at: 1.day.ago, transaction_source: raw_stripe_transaction
      )
    end.to have_enqueued_job(CardLocking::MaterializeChargeJob).at_least(:once)

    primary_mapping = canonical_transaction.reload.ledger_item.primary_mapping
    expect(primary_mapping).to be_present
    expect(primary_mapping.ledger.event).to eq(event)
    expect(primary_mapping.mapped_by).to be_nil
  end

  it "does not enqueue the materialize job for a non-card, positive-amount mapping" do
    canonical_transaction = create(:canonical_transaction, amount_cents: 10_00)

    expect { create(:canonical_event_mapping, canonical_transaction:, event:) }
      .not_to have_enqueued_job(CardLocking::MaterializeChargeJob)
  end
end
