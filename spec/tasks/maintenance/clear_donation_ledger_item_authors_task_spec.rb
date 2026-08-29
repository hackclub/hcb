# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::ClearDonationLedgerItemAuthorsTask do
  include DonationSupport

  before { stub_donation_payment_intent_creation }

  # `refresh!` no longer computes an author for a donation, so a stale
  # author_id has to be written directly to stand in for what the pre-change
  # code cached.
  def donation_item(author: nil)
    donation = create(:donation, in_person: true, collected_by: create(:user))
    item = Ledger::Item.new(
      amount_cents: 1000,
      memo: "Donation",
      datetime: Time.current,
      linked_object: donation
    )
    item.save(validate: false)
    item.update_columns(author_id: author&.id)
    item
  end

  it "clears the collecting organizer cached on an in-person donation" do
    item = donation_item(author: create(:user))

    described_class.new.process(item)

    expect(item.reload.author).to be_nil
  end

  it "collects only the donations that still have an author" do
    stale = donation_item(author: create(:user))
    already_cleared = donation_item

    expect(described_class.new.collection).to include(stale)
    expect(described_class.new.collection).not_to include(already_cleared)
  end
end
