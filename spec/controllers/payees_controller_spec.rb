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

    it "reports no duplicate when the email is unused" do
      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("duplicate" => false)
    end

    it "reports no duplicate when the email is blank" do
      get :check_email, params: { event_id: event.slug, email: "  " }

      expect(response.parsed_body).to eq("duplicate" => false)
    end

    it "reports a duplicate, normalizing case and whitespace, with the matching names" do
      existing = event.payees.create!(display_name: "Orpheus", email: "orpheus@hackclub.com")

      get :check_email, params: { event_id: event.slug, email: "  Orpheus@Hackclub.com  " }

      expect(response.parsed_body).to eq(
        "duplicate" => true,
        "email"     => "orpheus@hackclub.com",
        "names"     => [existing.display_name]
      )
    end

    it "lists every non-archived recipient sharing the email, oldest first" do
      first = event.payees.create!(display_name: "Orpheus Inc.", email: "orpheus@hackclub.com")
      second = event.payees.create!(display_name: "Orpheus LLC", email: "orpheus@hackclub.com")
      archived = event.payees.create!(display_name: "Old Orpheus", email: "orpheus@hackclub.com")
      archived.archive!

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(true)
      expect(response.parsed_body["names"]).to eq([first.display_name, second.display_name])
    end

    it "excludes the recipient being edited from its own duplicate check" do
      editing = event.payees.create!(display_name: "Orpheus", email: "orpheus@hackclub.com")

      get :check_email, params: {
        event_id: event.slug,
        email: "orpheus@hackclub.com",
        exclude_payee_id: editing.hashid
      }

      expect(response.parsed_body).to eq("duplicate" => false)
    end

    it "still flags other recipients when excluding the one being edited" do
      editing = event.payees.create!(display_name: "Orpheus", email: "orpheus@hackclub.com")
      other = event.payees.create!(display_name: "Orpheus LLC", email: "orpheus@hackclub.com")

      get :check_email, params: {
        event_id: event.slug,
        email: "orpheus@hackclub.com",
        exclude_payee_id: editing.hashid
      }

      expect(response.parsed_body["duplicate"]).to be(true)
      expect(response.parsed_body["names"]).to eq([other.display_name])
    end

    it "scopes matches to the current event" do
      other_event = create(:event, organizers: [user])
      other_event.payees.create!(display_name: "Orpheus", email: "orpheus@hackclub.com")

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body).to eq("duplicate" => false)
    end
  end

end
