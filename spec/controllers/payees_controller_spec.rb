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

  describe "GET #check_email" do
    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      create_session(user, verified: true)
    end

    it "flags an existing recipient with the same email" do
      payee = create(:payee, event:, display_name: "Orpheus", email: "orpheus@hackclub.com", legal_entity: nil)

      get :check_email, params: { event_id: event.slug, email: "Orpheus@Hackclub.com" }

      body = response.parsed_body
      expect(body["duplicate"]).to be(true)
      expect(body["payees"].length).to eq(1)
      expect(body["payees"].first["name"]).to eq("Orpheus")
      expect(body["payees"].first["select_url"]).to eq(
        new_event_payment_path(event_id: event.slug, payee_id: payee.hashid)
      )
    end

    it "builds a contractor select url when destination is contractors" do
      payee = create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: nil)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com", destination: "contractors" }

      expect(response.parsed_body["payees"].first["select_url"]).to eq(
        new_event_payroll_position_path(event_id: event.slug, payee_id: payee.hashid)
      )
    end

    it "does not flag when no recipient matches" do
      get :check_email, params: { event_id: event.slug, email: "nobody@hackclub.com" }

      expect(response.parsed_body).to eq({ "duplicate" => false, "payees" => [] })
    end

    it "ignores archived recipients" do
      create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: nil, archived_at: Time.current)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end

    it "returns no duplicate for a blank email" do
      get :check_email, params: { event_id: event.slug, email: "" }

      expect(response.parsed_body).to eq({ "duplicate" => false })
    end
  end

end
