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
    end
  end

  describe "PATCH #update" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }
    let(:payee) { create(:payee, event:, email: "old@example.com", legal_entity: nil) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      create_session(user, verified: true)
    end

    it "updates the email when no payment has been sent" do
      patch :update, params: { event_id: event.slug, id: payee.hashid, payee: { display_name: payee.display_name, email: "new@example.com" } }

      expect(payee.reload.email).to eq("new@example.com")
      expect(flash[:success]).to eq("Recipient updated.")
    end

    it "re-addresses an in-flight contractor agreement to the new email" do
      stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(status: 201, body: [{ submission_id: "STUBBED" }].to_json, headers: { content_type: "application/json" })
      stub_request(:get, "https://api.docuseal.co/submissions/STUBBED")
        .to_return(status: 200, body: { submitters: [{ role: "HCB", slug: "h" }, { role: "Organizer", slug: "o" }, { role: "Contractor", slug: "c" }] }.to_json, headers: { content_type: "application/json" })

      position = create(:payroll_position, payee:)
      contract = position.send_contract(organizer_user: user)
      contract.party(:hcb).mark_signed!

      patch :update, params: { event_id: event.slug, id: payee.hashid, payee: { display_name: payee.display_name, email: "new@example.com" } }

      expect(contract.reload).to be_sent
      expect(position.contracts.reload.sole).to eq(contract)
      expect(contract.party(:contractor).email).to eq("new@example.com")
      expect(flash[:success]).to include("re-sent to new@example.com")
    end

    it "refuses the email change once the recipient has claimed the payee" do
      payee.update!(legal_entity: create(:legal_entity))

      patch :update, params: { event_id: event.slug, id: payee.hashid, payee: { display_name: payee.display_name, email: "new@example.com" } }

      expect(payee.reload.email).to eq("old@example.com")
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses the email change once a payment has been sent" do
      create(:payment, :sent, payee:)

      patch :update, params: { event_id: event.slug, id: payee.hashid, payee: { display_name: payee.display_name, email: "new@example.com" } }

      expect(payee.reload.email).to eq("old@example.com")
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "still allows renaming a recipient whose email is locked" do
      create(:payment, :sent, payee:)

      patch :update, params: { event_id: event.slug, id: payee.hashid, payee: { display_name: "Renamed", email: payee.email } }

      expect(payee.reload.display_name).to eq("Renamed")
      expect(flash[:success]).to eq("Recipient updated.")
    end
  end

end
