# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayeesController do
  include SessionSupport

  let(:user) { create(:user) }
  let(:event) { create(:event, organizers: [user]) }

  describe "GET #check_duplicate" do
    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    it "flags an email that already belongs to a recipient in the event" do
      existing = create(:payee, event:, display_name: "Orpheus", email: "orpheus@hackclub.com")

      get :check_duplicate, params: { event_id: event.slug, email: "Orpheus@hackclub.com" }

      body = response.parsed_body
      expect(body["duplicate"]).to be(true)
      expect(body["recipients"]).to eq([{ "name" => existing.display_name, "email" => existing.email }])
    end

    it "does not flag an email with no matching recipient" do
      create(:payee, event:, email: "orpheus@hackclub.com")

      get :check_duplicate, params: { event_id: event.slug, email: "someone-else@hackclub.com" }

      body = response.parsed_body
      expect(body["duplicate"]).to be(false)
      expect(body["recipients"]).to eq([])
    end

    it "ignores recipients from other events" do
      other_event = create(:event)
      create(:payee, event: other_event, email: "orpheus@hackclub.com")

      get :check_duplicate, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end

    it "ignores archived recipients" do
      create(:payee, event:, email: "orpheus@hackclub.com").archive!

      get :check_duplicate, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end

    it "returns no duplicate for a blank email" do
      get :check_duplicate, params: { event_id: event.slug, email: "" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end
  end

  describe "POST #create" do
    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    context "on the manual path" do
      before do
        Flipper.enable(:manual_payees_2026_08_05, event)
      end

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

end
