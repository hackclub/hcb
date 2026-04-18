# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionGroupingEngine::Transaction::FilterTypePreloader do
  let(:event) { create(:event) }

  def settled_for(event)
    TransactionGroupingEngine::Transaction::All.new(event_id: event.id).run
  end

  def hcb_code_query_count(&block)
    count = 0
    callback = ->(*, payload) { count += 1 if payload[:sql].include?(%("hcb_codes")) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    count
  end

  describe "#run!" do
    context "when type is blank" do
      it "is a no-op (does not assign local_hcb_code)" do
        create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction))
        settled = settled_for(event)

        described_class.new(settled_transactions: settled, type: nil).run!

        expect(settled.first.instance_variable_get(:@local_hcb_code)).to be_nil
      end
    end

    context "when settled_transactions is empty" do
      it "does not raise" do
        expect {
          described_class.new(settled_transactions: [], type: "card_charge").run!
        }.not_to raise_error
      end
    end

    it "assigns local_hcb_code on every row" do
      2.times { create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction)) }
      settled = settled_for(event)

      described_class.new(settled_transactions: settled, type: "ach_transfer").run!

      settled.each do |t|
        local = t.instance_variable_get(:@local_hcb_code)
        expect(local).to be_a(HcbCode)
        expect(local.hcb_code).to eq(t.hcb_code)
      end
    end

    it "loads hcb_codes in a single query regardless of row count" do
      4.times { create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction)) }
      settled = settled_for(event)

      count = hcb_code_query_count do
        described_class.new(settled_transactions: settled, type: "ach_transfer").run!
      end

      expect(count).to eq(1)
    end

    # `CanonicalTransaction#after_create :write_hcb_code` and
    # `CanonicalEventMapping#after_create` (which calls write_hcb_code on the
    # mapping's CT) both recompute hcb_code from the row's source, so passing
    # `hcb_code:` to the factory doesn't stick. Use `update_column` after both
    # are created and ensure the matching HcbCode row exists.
    def make_disbursement_settled_tx(event, disbursement, hcb_code:, amount_cents:)
      ct = create(:canonical_transaction, amount_cents:)
      create(:canonical_event_mapping, event:, canonical_transaction: ct)
      ct.update_column(:hcb_code, hcb_code)
      HcbCode.find_or_create_by(hcb_code:)
      ct
    end

    %w[card_charge hcb_transfer ach_transfer donation invoice].each do |type|
      it "produces the same filter result as without preload (type=#{type})" do
        # Mix of plain CTs and a disbursement-flavored row, to exercise the
        # different code paths.
        4.times { create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction)) }

        disbursement = create(:disbursement, source_event: event, event: create(:event))
        make_disbursement_settled_tx(event, disbursement,
                                     hcb_code: disbursement.outgoing_hcb_code,
                                     amount_cents: -disbursement.amount)

        baseline = ::EventsController.filter_transaction_type(
          type,
          settled_transactions: settled_for(event),
          pending_transactions: []
        )[:settled_transactions].map(&:hcb_code).sort

        preloaded_settled = settled_for(event)
        described_class.new(settled_transactions: preloaded_settled, type:).run!
        preloaded = ::EventsController.filter_transaction_type(
          type,
          settled_transactions: preloaded_settled,
          pending_transactions: []
        )[:settled_transactions].map(&:hcb_code).sort

        expect(preloaded).to eq(baseline)
      end
    end

    context "with type: 'hcb_transfer'" do
      it "preloads outgoing_disbursement so subsequent reads do not query" do
        disbursement = create(:disbursement, source_event: event, event: create(:event))
        make_disbursement_settled_tx(event, disbursement,
                                     hcb_code: disbursement.outgoing_hcb_code,
                                     amount_cents: -disbursement.amount)

        settled = settled_for(event)
        described_class.new(settled_transactions: settled, type: "hcb_transfer").run!

        local = settled.first.instance_variable_get(:@local_hcb_code)
        expect(local.outgoing_disbursement?).to be true

        allow(Disbursement).to receive(:find_by).and_call_original
        local.outgoing_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end

      it "preloads incoming_disbursement so subsequent reads do not query" do
        disbursement = create(:disbursement, source_event: create(:event), event: event)
        make_disbursement_settled_tx(event, disbursement,
                                     hcb_code: disbursement.incoming_hcb_code,
                                     amount_cents: disbursement.amount)

        settled = settled_for(event)
        described_class.new(settled_transactions: settled, type: "hcb_transfer").run!

        local = settled.first.instance_variable_get(:@local_hcb_code)
        expect(local.incoming_disbursement?).to be true

        allow(Disbursement).to receive(:find_by).and_call_original
        local.incoming_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end
    end

    context "with type: 'card_charge'" do
      it "preloads canonical_transactions and their raw_stripe_transaction" do
        rst = create(:raw_stripe_transaction)
        ct = create(:canonical_transaction, transaction_source: rst)
        create(:canonical_event_mapping, event:, canonical_transaction: ct)

        settled = settled_for(event)
        described_class.new(settled_transactions: settled, type: "card_charge").run!

        cts = settled.first.canonical_transactions
        expect(cts.map(&:id)).to eq([ct.id])

        # The writer should have set @raw_stripe_transaction directly, so
        # accessing it doesn't go back to the DB.
        allow(RawStripeTransaction).to receive(:find).and_call_original
        expect(cts.first.raw_stripe_transaction.id).to eq(rst.id)
        expect(RawStripeTransaction).not_to have_received(:find)
      end
    end
  end
end
