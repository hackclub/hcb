# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DetectLogicalTransactionAnomaliesJob do
  describe "#perform" do
    let(:event) { create(:event) }
    let(:other_event) { create(:event) }
    let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

    def map_to_event_ledger(item)
      Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
    end

    # HcbCode's after_create callback derives event_id from the code's transactions and
    # writes nil when there are none, so these columns have to be set past the callback.
    def create_hcb_code(event_id:, ledger_item_id:)
      create(:hcb_code).tap do |hcb_code|
        hcb_code.update_columns(event_id:, ledger_item_id:)
      end
    end

    def reported_ledger_items
      captured = nil
      allow(AdminMailer).to receive(:logical_transaction_anomalies) do |**kwargs|
        captured = kwargs[:ledger_items].to_a
        delivery
      end

      described_class.perform_now(event_id: event.id)

      captured || []
    end

    it "reports an item on the event's ledger that no HCB code points at" do
      orphan = create(:ledger_item)
      map_to_event_ledger(orphan)

      expect(reported_ledger_items).to include(orphan)
    end

    it "reports orphans even when the event has an HCB code with no ledger item" do
      orphan = create(:ledger_item)
      map_to_event_ledger(orphan)
      create_hcb_code(event_id: event.id, ledger_item_id: nil)

      expect(reported_ledger_items).to include(orphan)
    end

    it "does not report an item that an HCB code of the event points at" do
      linked = create(:ledger_item)
      map_to_event_ledger(linked)
      create_hcb_code(event_id: event.id, ledger_item_id: linked.id)

      expect(reported_ledger_items).not_to include(linked)
    end

    it "reports an item whose HCB code belongs to a different event" do
      crossed = create(:ledger_item)
      map_to_event_ledger(crossed)
      create_hcb_code(event_id: other_event.id, ledger_item_id: crossed.id)

      expect(reported_ledger_items).to include(crossed)
    end

    it "ignores items that are not on the event's ledger" do
      elsewhere = create(:ledger_item)
      Ledger::Mapping.create!(ledger: other_event.ledger, ledger_item: elsewhere, on_primary_ledger: true)

      expect(reported_ledger_items).not_to include(elsewhere)
    end
  end
end
