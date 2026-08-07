# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCode, type: :model do
  describe "disbursement integration" do
    describe "#outgoing_disbursement?" do
      it "returns true for HCB-500-* codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-500-#{disbursement.id}")

        expect(hcb_code.outgoing_disbursement?).to be true
      end

      it "returns false for HCB-550-* codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-550-#{disbursement.id}")

        expect(hcb_code.outgoing_disbursement?).to be false
      end
    end

    describe "#incoming_disbursement?" do
      it "returns true for HCB-550-* codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-550-#{disbursement.id}")

        expect(hcb_code.incoming_disbursement?).to be true
      end

      it "returns false for HCB-500-* codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-500-#{disbursement.id}")

        expect(hcb_code.incoming_disbursement?).to be false
      end
    end

    describe "#outgoing_disbursement" do
      it "returns nil for non-disbursement codes" do
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-100-1")
        expect(hcb_code.outgoing_disbursement).to be_nil
      end

      it "memoizes the result so repeated calls do not query" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)
        hcb_code.outgoing_disbursement # populate

        allow(Disbursement).to receive(:find_by).and_call_original
        hcb_code.outgoing_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end

      it "memoizes nil results too (so a missing disbursement doesn't re-query)" do
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-500-0")
        expect(hcb_code.outgoing_disbursement).to be_nil

        allow(Disbursement).to receive(:find_by).and_call_original
        hcb_code.outgoing_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end

      it "honors the writer (used by FilterTypePreloader)" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        sentinel = Object.new
        hcb_code.outgoing_disbursement = sentinel
        expect(hcb_code.outgoing_disbursement).to equal(sentinel)
      end

      it "resolves to the outgoing lens with a negative amount" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.outgoing_disbursement).to be_a(Disbursement::Outgoing)
        expect(hcb_code.outgoing_disbursement.id).to eq(disbursement.id)
        expect(hcb_code.outgoing_disbursement.amount).to eq(-disbursement.amount)
      end
    end

    describe "#incoming_disbursement" do
      it "returns nil for non-disbursement codes" do
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-100-1")
        expect(hcb_code.incoming_disbursement).to be_nil
      end

      it "memoizes the result so repeated calls do not query" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)
        hcb_code.incoming_disbursement # populate

        allow(Disbursement).to receive(:find_by).and_call_original
        hcb_code.incoming_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end

      it "memoizes nil results too" do
        hcb_code = HcbCode.find_or_create_by(hcb_code: "HCB-550-0")
        expect(hcb_code.incoming_disbursement).to be_nil

        allow(Disbursement).to receive(:find_by).and_call_original
        hcb_code.incoming_disbursement
        expect(Disbursement).not_to have_received(:find_by)
      end

      it "honors the writer (used by FilterTypePreloader)" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        sentinel = Object.new
        hcb_code.incoming_disbursement = sentinel
        expect(hcb_code.incoming_disbursement).to equal(sentinel)
      end

      it "resolves to the incoming lens with a positive amount" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        expect(hcb_code.incoming_disbursement).to be_a(Disbursement::Incoming)
        expect(hcb_code.incoming_disbursement.id).to eq(disbursement.id)
        expect(hcb_code.incoming_disbursement.amount).to eq(disbursement.amount)
      end
    end

    describe "#amount_cents_by_event" do
      let(:event) { create(:event) }

      it "returns the negative outgoing amount for an outgoing disbursement code" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.amount_cents_by_event(event)).to eq(-disbursement.amount)
      end

      it "returns the positive incoming amount for an incoming disbursement code" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        expect(hcb_code.amount_cents_by_event(event)).to eq(disbursement.amount)
      end

      it "resolves disbursement amounts without the deprecated HcbCode#disbursement accessors" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(Rails.application.deprecators[:hcb]).not_to receive(:warn)
        hcb_code.amount_cents_by_event(event)
      end
    end

    # The goal is to deprecate this method entirely with the disbursement splitting work
    describe "#events" do
      context "with a disbursement that has canonical pending transactions" do
        let(:source_event) { create(:event) }
        let(:destination_event) { create(:event) }
        let(:disbursement) do
          create(:disbursement, source_event: source_event, event: destination_event)
        end

        before do
          # Create CPTs for the disbursement with both events
          outgoing_cpt = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
          outgoing_cpt.update_column(:hcb_code, disbursement.outgoing_hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: outgoing_cpt, event: source_event)

          incoming_cpt = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
          incoming_cpt.update_column(:hcb_code, disbursement.outgoing_hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: incoming_cpt, event: destination_event)
        end

        it "returns both source and destination events" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.outgoing_hcb_code)
          hcb_code.instance_variable_set(:@events, nil)

          expect(hcb_code.events).to contain_exactly(source_event, destination_event)
        end
      end

      context "with a disbursement that has no transactions" do
        let(:source_event) { create(:event) }
        let(:destination_event) { create(:event) }
        let(:disbursement) do
          create(:disbursement, source_event: source_event, event: destination_event)
        end

        it "falls back to the disbursement's source event for outgoing hcb_code" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.outgoing_hcb_code)

          expect(hcb_code.events).to include(source_event)
        end

        it "falls back to the disbursement's destination event for incoming hcb_code" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.incoming_hcb_code)

          expect(hcb_code.events).to include(destination_event)
        end
      end
    end

    describe "#event" do
      context "with a disbursement that has canonical pending transactions" do
        let(:source_event) { create(:event) }
        let(:destination_event) { create(:event) }
        let(:disbursement) do
          create(:disbursement, source_event: source_event, event: destination_event)
        end

        before do
          outgoing_cpt = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
          outgoing_cpt.update_column(:hcb_code, disbursement.outgoing_hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: outgoing_cpt, event: source_event)
        end

        it "returns the first event" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.outgoing_hcb_code)
          hcb_code.instance_variable_set(:@events, nil)

          expect(hcb_code.event).to eq(source_event)
        end
      end
    end

    describe "#type" do
      it "returns :disbursement for outgoing disbursement codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.type).to eq(:disbursement)
      end

      it "returns :disbursement for incoming disbursement codes" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        expect(hcb_code.type).to eq(:disbursement)
      end

      context "with a card grant disbursement" do
        it "returns :card_grant" do
          disbursement = create(:disbursement)
          stripe_card = create(:stripe_card, :with_stripe_id)
          user = create(:user)
          sent_by = create(:user)

          # Insert card_grant directly via SQL to bypass all callbacks
          CardGrant.insert!({
                              disbursement_id: disbursement.id,
                              event_id: disbursement.source_event.id,
                              stripe_card_id: stripe_card.id,
                              user_id: user.id,
                              sent_by_id: sent_by.id,
                              email: "test@example.com",
                              amount_cents: 1000,
                              invite_message: "Test invite message",
                              expiration_at: 1.year.from_now,
                              created_at: Time.current,
                              updated_at: Time.current
                            })

          hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

          expect(hcb_code.type).to eq(:card_grant)
        end
      end
    end

    describe "#shared_commentable?" do
      let(:disbursement) { create(:disbursement) }

      it "returns true for outgoing disbursement codes" do
        outgoing = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(outgoing.shared_commentable?).to be true
      end

      it "returns true for incoming disbursement codes" do
        incoming = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        expect(incoming.shared_commentable?).to be true
      end

      it "returns false for non-disbursement codes" do
        hcb_code = create(:hcb_code)

        expect(hcb_code.shared_commentable?).to be false
      end
    end

    describe "#shared_commentable" do
      let(:disbursement) { create(:disbursement) }

      it "returns the Disbursement for outgoing disbursement codes" do
        outgoing = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(outgoing.shared_commentable).to eq(disbursement)
      end

      it "returns the Disbursement for incoming disbursement codes" do
        incoming = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)

        expect(incoming.shared_commentable).to eq(disbursement)
      end

      it "returns nil for non-disbursement codes" do
        hcb_code = create(:hcb_code)

        expect(hcb_code.shared_commentable).to be_nil
      end
    end

    describe "#all_comments" do
      let(:disbursement) { create(:disbursement) }
      let(:user) { create(:user) }

      it "includes comments on both the HcbCode and the Disbursement" do
        outgoing = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)
        hcb_code_comment = create(:comment, commentable: outgoing, user:)
        disbursement_comment = create(:comment, commentable: disbursement, user:)

        expect(outgoing.all_comments).to include(hcb_code_comment, disbursement_comment)
      end

      it "does not include comments from the paired HcbCode" do
        outgoing = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)
        incoming = HcbCode.find_or_create_by(hcb_code: disbursement.incoming_hcb_code)
        incoming_comment = create(:comment, commentable: incoming, user:)

        expect(outgoing.all_comments).not_to include(incoming_comment)
      end

      it "returns regular comments for non-disbursement codes" do
        hcb_code = create(:hcb_code)
        comment = create(:comment, commentable: hcb_code, user:)

        expect(hcb_code.all_comments).to include(comment)
      end
    end

    describe "#humanized_type" do
      it "returns 'Transfer' for disbursements" do
        disbursement = create(:disbursement)
        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.humanized_type).to eq("Transfer")
      end

      it "returns 'Card grant' for card grant disbursements" do
        disbursement = create(:disbursement)
        stripe_card = create(:stripe_card, :with_stripe_id)
        user = create(:user)
        sent_by = create(:user)

        # Insert card_grant directly via SQL to bypass all callbacks
        CardGrant.insert!({
                            disbursement_id: disbursement.id,
                            event_id: disbursement.source_event.id,
                            stripe_card_id: stripe_card.id,
                            user_id: user.id,
                            sent_by_id: sent_by.id,
                            email: "test@example.com",
                            amount_cents: 1000,
                            invite_message: "Test invite message",
                            expiration_at: 1.year.from_now,
                            created_at: Time.current,
                            updated_at: Time.current
                          })

        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.humanized_type).to eq("Card grant")
      end
    end
  end

  describe "#update_custom_memo!" do
    # `custom_memo` is stored on every canonical (pending) transaction in the
    # group *and* on their ledger items, which cache `memo` from their own copy.
    it "writes every canonical transaction in the group and their ledger items" do
      first = create(:canonical_transaction)
      second = create(:canonical_transaction)
      second.update_column(:hcb_code, first.hcb_code)

      first.local_hcb_code.update_custom_memo!("Snacks at Shelburne Market")

      expect(first.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(second.reload.custom_memo).to eq("Snacks at Shelburne Market")
      # Assert `custom_memo`, not `memo` — `fallback_memo` reads the canonical
      # transaction's memo, so `memo` looks right even when the item is desynced.
      expect(first.ledger_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(second.ledger_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
    end

    # A transaction whose ledger item was never assigned (the assignment runs in
    # an `after_create_commit` wrapped in `safely`) must still be renamed — it is
    # the only copy of the memo it has.
    it "writes transactions that have no ledger item alongside those that do" do
      with_item = create(:canonical_transaction)
      without_item = create(:canonical_transaction)
      without_item.update_column(:hcb_code, with_item.hcb_code)
      without_item.update_column(:ledger_item_id, nil)
      # Neither the HCB code nor this transaction can reach the ledger item, so
      # only `with_item` leads to it.
      with_item.local_hcb_code.update_columns(ledger_item_id: nil)

      with_item.local_hcb_code.reload.update_custom_memo!("Snacks at Shelburne Market")

      expect(with_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(without_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(with_item.ledger_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
    end

    # `hcb_codes.ledger_item_id` is only back-linked when the transaction engine
    # creates the item, so it can be null while the transactions still point at
    # one. The rename has to find the item through them.
    it "reaches the ledger item when the HCB code is not back-linked to it" do
      canonical_transaction = create(:canonical_transaction)
      ledger_item = canonical_transaction.reload.ledger_item
      hcb_code = canonical_transaction.local_hcb_code
      hcb_code.update_columns(ledger_item_id: nil)

      hcb_code.reload.update_custom_memo!("Snacks at Shelburne Market")

      expect(canonical_transaction.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(ledger_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(ledger_item.memo).to eq("Snacks at Shelburne Market")
    end
  end
end
