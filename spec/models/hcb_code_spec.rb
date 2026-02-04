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
          outgoing_cpt.update_column(:hcb_code, disbursement.hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: outgoing_cpt, event: source_event)

          incoming_cpt = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
          incoming_cpt.update_column(:hcb_code, disbursement.hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: incoming_cpt, event: destination_event)
        end

        it "returns both source and destination events" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.hcb_code)
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
          outgoing_cpt.update_column(:hcb_code, disbursement.hcb_code)
          create(:canonical_pending_event_mapping, canonical_pending_transaction: outgoing_cpt, event: source_event)
        end

        it "returns the first event" do
          hcb_code = HcbCode.find_by(hcb_code: disbursement.hcb_code)
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
                              created_at: Time.current,
                              updated_at: Time.current
                            })

          hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

          expect(hcb_code.type).to eq(:card_grant)
        end
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
                            created_at: Time.current,
                            updated_at: Time.current
                          })

        hcb_code = HcbCode.find_or_create_by(hcb_code: disbursement.outgoing_hcb_code)

        expect(hcb_code.humanized_type).to eq("Card grant")
      end
    end
  end
end
