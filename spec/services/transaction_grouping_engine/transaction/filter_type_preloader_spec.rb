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

    # Accuracy / data-integrity guarantees: the preloader must attach the
    # *exact same* records the lazy path would have loaded — anything else
    # could surface as a financial data leak.
    describe "preload accuracy" do
      it "attaches the same local_hcb_code (by id) the lazy path would load" do
        3.times { create(:canonical_event_mapping, event:, canonical_transaction: create(:canonical_transaction)) }

        baseline = settled_for(event)
        baseline_ids_by_code = baseline.to_h { |t| [t.hcb_code, t.local_hcb_code.id] }

        preloaded = settled_for(event)
        described_class.new(settled_transactions: preloaded, type: "ach_transfer").run!

        preloaded.each do |t|
          local = t.instance_variable_get(:@local_hcb_code)
          expect(local.id).to eq(baseline_ids_by_code.fetch(t.hcb_code))
          expect(local.hcb_code).to eq(t.hcb_code)
        end
      end

      context "with type: 'hcb_transfer'" do
        it "attaches the same Disbursement (by id) the lazy path would load" do
          # one outgoing + one incoming row to exercise both writers
          outgoing_disb = create(:disbursement, source_event: event, event: create(:event))
          incoming_disb = create(:disbursement, source_event: create(:event), event: event)
          make_disbursement_settled_tx(event, outgoing_disb,
                                       hcb_code: outgoing_disb.outgoing_hcb_code,
                                       amount_cents: -outgoing_disb.amount)
          make_disbursement_settled_tx(event, incoming_disb,
                                       hcb_code: incoming_disb.incoming_hcb_code,
                                       amount_cents: incoming_disb.amount)

          baseline = settled_for(event)
          baseline_disb_ids = baseline.to_h do |t|
            local = t.local_hcb_code
            disb_id =
              if local.outgoing_disbursement?
                local.outgoing_disbursement&.disbursement&.id
              elsif local.incoming_disbursement?
                local.incoming_disbursement&.disbursement&.id
              end
            [t.hcb_code, disb_id]
          end

          preloaded = settled_for(event)
          described_class.new(settled_transactions: preloaded, type: "hcb_transfer").run!

          preloaded.each do |t|
            local = t.instance_variable_get(:@local_hcb_code)
            attached =
              if local.outgoing_disbursement?
                local.outgoing_disbursement&.disbursement&.id
              elsif local.incoming_disbursement?
                local.incoming_disbursement&.disbursement&.id
              end
            expect(attached).to eq(baseline_disb_ids.fetch(t.hcb_code))
          end
        end

        it "never assigns outgoing_disbursement onto an incoming HcbCode (or vice versa)" do
          outgoing_disb = create(:disbursement, source_event: event, event: create(:event))
          incoming_disb = create(:disbursement, source_event: create(:event), event: event)
          make_disbursement_settled_tx(event, outgoing_disb,
                                       hcb_code: outgoing_disb.outgoing_hcb_code,
                                       amount_cents: -outgoing_disb.amount)
          make_disbursement_settled_tx(event, incoming_disb,
                                       hcb_code: incoming_disb.incoming_hcb_code,
                                       amount_cents: incoming_disb.amount)

          settled = settled_for(event)
          described_class.new(settled_transactions: settled, type: "hcb_transfer").run!

          settled.each do |t|
            local = t.instance_variable_get(:@local_hcb_code)
            outgoing_iv = local.instance_variable_defined?(:@outgoing_disbursement) ? local.instance_variable_get(:@outgoing_disbursement) : :unset
            incoming_iv = local.instance_variable_defined?(:@incoming_disbursement) ? local.instance_variable_get(:@incoming_disbursement) : :unset

            if local.outgoing_disbursement?
              expect(outgoing_iv).not_to eq(:unset), "outgoing HcbCode should have outgoing_disbursement preloaded"
              expect(incoming_iv).to eq(:unset), "outgoing HcbCode must NOT have incoming_disbursement assigned"
            elsif local.incoming_disbursement?
              expect(incoming_iv).not_to eq(:unset), "incoming HcbCode should have incoming_disbursement preloaded"
              expect(outgoing_iv).to eq(:unset), "incoming HcbCode must NOT have outgoing_disbursement assigned"
            end
          end
        end
      end

      context "with type: 'card_charge'" do
        it "attaches the same canonical_transactions and raw_stripe_transactions (by id) the lazy path would load" do
          rst1 = create(:raw_stripe_transaction)
          rst2 = create(:raw_stripe_transaction)
          ct1 = create(:canonical_transaction, transaction_source: rst1)
          ct2 = create(:canonical_transaction, transaction_source: rst2)
          create(:canonical_event_mapping, event:, canonical_transaction: ct1)
          create(:canonical_event_mapping, event:, canonical_transaction: ct2)

          baseline_settled = settled_for(event)
          baseline_by_hcb_code = baseline_settled.to_h do |t|
            [t.hcb_code, {
              ct_ids: t.canonical_transactions.map(&:id).sort,
              rst_id: t.canonical_transactions.first.raw_stripe_transaction&.id,
            }]
          end

          preloaded = settled_for(event)
          described_class.new(settled_transactions: preloaded, type: "card_charge").run!

          preloaded.each do |t|
            attached_ct_ids = t.canonical_transactions.map(&:id).sort
            attached_rst_id = t.canonical_transactions.first.raw_stripe_transaction&.id
            expected = baseline_by_hcb_code.fetch(t.hcb_code)
            expect(attached_ct_ids).to eq(expected[:ct_ids])
            expect(attached_rst_id).to eq(expected[:rst_id])
          end
        end
      end

      it "never attaches another event's HcbCode to a settled row" do
        # Two events with disbursement-flavored rows of similar shape.
        other_event = create(:event)
        disb_a = create(:disbursement, source_event: event, event: create(:event))
        disb_b = create(:disbursement, source_event: other_event, event: create(:event))
        make_disbursement_settled_tx(event, disb_a,
                                     hcb_code: disb_a.outgoing_hcb_code,
                                     amount_cents: -disb_a.amount)
        make_disbursement_settled_tx(other_event, disb_b,
                                     hcb_code: disb_b.outgoing_hcb_code,
                                     amount_cents: -disb_b.amount)

        settled = settled_for(event)
        # Sanity: the engine itself only returned event A's rows.
        expect(settled.map(&:hcb_code)).to contain_exactly(disb_a.outgoing_hcb_code)

        described_class.new(settled_transactions: settled, type: "hcb_transfer").run!

        settled.each do |t|
          local = t.instance_variable_get(:@local_hcb_code)
          # The HcbCode for disb_b must never be attached to a row from event A.
          expect(local.hcb_code).not_to eq(disb_b.outgoing_hcb_code)
          expect(local.hcb_code).to eq(t.hcb_code)
        end
      end
    end
  end
end
