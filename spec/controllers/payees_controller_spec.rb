# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayeesController do
  include SessionSupport

  describe "POST #create" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    context "on the manual path" do
      it "creates a payee and a managed legal entity, then redirects with the payee selected" do
        expect do
          post :create, params: {
            event_id: event.slug,
            name: "Orpheus",
            email: "orpheus@hackclub.com",
            payee_entity_type: "person",
            manual: "true"
          }
        end.to change(Payee, :count).by(1).and change(LegalEntity, :count).by(1)

        payee = event.payees.last
        expect(payee.display_name).to eq("Orpheus")
        expect(payee.legal_entity).to be_present
        expect(payee.legal_entity.managing_event).to eq(event)
        expect(payee.legal_entity.entity_type).to eq("person")
        expect(response).to redirect_to(
          new_event_payment_path(event_id: event.slug, payee_id: payee.hashid)
        )
      end

      it "prefills the payout method from transfers this event already sent to that email" do
        create(:canonical_pending_transaction, amount_cents: 1_000_000, event:, fronted: true)
        create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                              account_number: "123456789", routing_number: "110000000")

        post :create, params: {
          event_id: event.slug,
          name: "Orpheus",
          email: "orpheus@hackclub.com",
          payee_entity_type: "person",
          manual: "true"
        }

        details = event.payees.last.legal_entity.default_payout_method.details
        expect(details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
        expect(details.account_number).to eq("123456789")
      end

      it "rejects a missing recipient type without creating anything" do
        expect do
          post :create, params: {
            event_id: event.slug,
            name: "Orpheus",
            email: "orpheus@hackclub.com",
            payee_entity_type: "",
            manual: "true"
          }
        end.to change(Payee, :count).by(0).and change(LegalEntity, :count).by(0)

        expect(response).to redirect_to(
          new_event_payment_path(event_id: event.slug)
        )
      end
    end

    context "on the contractor (non-manual) path" do
      it "creates a payee without a legal entity" do
        expect do
          post :create, params: {
            event_id: event.slug,
            name: "Orpheus",
            email: "orpheus@hackclub.com"
          }
        end.to change(Payee, :count).by(1).and change(LegalEntity, :count).by(0)

        payee = event.payees.last
        expect(payee.legal_entity).to be_nil
        expect(response).to redirect_to(
          new_event_payment_path(event_id: event.slug, payee_id: payee.hashid)
        )
      end

      # The recipient onboards themselves here, so nothing about a matching email
      # address should hand them payout details someone else entered.
      it "does not prefill a payout method from legacy transfers" do
        create(:canonical_pending_transaction, amount_cents: 1_000_000, event:, fronted: true)
        create(:ach_transfer, event:, recipient_name: "Orpheus", recipient_email: "orpheus@hackclub.com",
                              account_number: "123456789", routing_number: "110000000")

        expect do
          post :create, params: {
            event_id: event.slug,
            name: "Orpheus",
            email: "orpheus@hackclub.com"
          }
        end.not_to change(LegalEntity::PayoutMethod, :count)
      end
    end
  end

end
