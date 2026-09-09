# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillLedgerItemTimestampsTask, type: :model do
  def run_task
    task = described_class.new
    task.collection.each { |ledger_item| task.process(ledger_item) }
  end

  def ledger_item(datetime: Time.current)
    Ledger::Item.new(amount_cents: 0, memo: "Test", datetime:).tap { |item| item.save(validate: false) }
  end

  it "backfills the timestamps and moves datetime to the settling transaction" do
    item = ledger_item(datetime: 1.day.ago)
    cpt = create(:canonical_pending_transaction, date: 5.days.ago, created_at: 5.days.ago, ledger_item_id: item.id)
    ct = create(:canonical_transaction, date: 3.days.ago, created_at: 3.days.ago, ledger_item_id: item.id)

    run_task
    item.reload

    expect(item.pending_at).to be_within(1.second).of(cpt.created_at)
    expect(item.settled_at).to be_within(1.second).of(ct.created_at)
    expect(item.datetime).to be_within(1.second).of(ct.created_at)
  end

  it "skips items with no transactions and items already backfilled" do
    untouched = ledger_item(datetime: 1.day.ago)
    done = ledger_item
    create(:canonical_transaction, date: 3.days.ago, created_at: 3.days.ago, ledger_item_id: done.id)
    sentinel = 2.days.ago
    done.update_columns(settled_at: sentinel)

    expect(described_class.new.collection).to be_empty

    run_task

    expect(untouched.reload.pending_at).to be_nil
    expect(done.reload.settled_at).to be_within(1.second).of(sentinel)
  end

end
