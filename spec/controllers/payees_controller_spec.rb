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

    it "labels managed recipients" do
      legal_entity = create(:legal_entity, managing_event: event)
      create(:payee, event:, email: "orpheus@hackclub.com", legal_entity:)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["payees"].first["managed"]).to be(true)
    end

    it "returns the five most recent matches" do
      7.times { |i| create(:payee, event:, display_name: "Recipient #{i}", email: "orpheus@hackclub.com", legal_entity: nil, created_at: i.minutes.ago) }

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["payees"].map { |payee| payee["name"] }).to eq(
        ["Recipient 0", "Recipient 1", "Recipient 2", "Recipient 3", "Recipient 4"]
      )
    end

    it "ignores recipients belonging to another organization" do
      create(:payee, event: create(:event), email: "orpheus@hackclub.com", legal_entity: nil)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end

    it "ignores archived recipients" do
      create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: nil, archived_at: Time.current)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response.parsed_body["duplicate"]).to be(false)
    end

    it "returns no duplicate for a blank email" do
      get :check_email, params: { event_id: event.slug, email: "" }

      expect(response.parsed_body).to eq({ "duplicate" => false, "payees" => [] })
    end

    it "does not expose recipients to a user outside the organization" do
      create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: nil)
      create_session(create(:user), verified: true)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include("orpheus@hackclub.com")
    end

    it "does not expose recipients to a signed out user" do
      create(:payee, event:, email: "orpheus@hackclub.com", legal_entity: nil)
      cookies.delete(:session_token)

      get :check_email, params: { event_id: event.slug, email: "orpheus@hackclub.com" }

      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include("orpheus@hackclub.com")
    end
  end

  describe "GET #transfer_fee" do
    render_views

    let(:user) { create(:user) }
    let(:event) { create(:event, organizers: [user]) }
    let(:legal_entity) { create(:legal_entity) }
    let!(:payee) { create(:payee, event:, legal_entity:) }

    before do
      Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
      # Wire validations look the bank up on Column, which isn't what's under test here.
      legal_entity.payout_methods.new(default: true, details: build(:wire_payout_method_details)).save!(validate: false)
      create_session(user, verified: true)
    end

    it "shows the estimated fee and total for a low-value wire" do
      get :transfer_fee, params: { event_id: event.slug, id: payee.hashid, amount: "250.00" }

      expect(response.body).to include("estimated $25.00 fee to send this international wire, for a total of $275.00")
    end

    it "ignores non-positive or unparseable amounts" do
      ["-250", "0", "abc", ""].each do |amount|
        get :transfer_fee, params: { event_id: event.slug, id: payee.hashid, amount: }

        expect(response.body).not_to include("estimated"), "expected no fee for #{amount.inspect}"
      end
    end

    it "does not quote fees for another organization's recipient" do
      other_payee = create(:payee, event: create(:event), legal_entity:)

      expect do
        get :transfer_fee, params: { event_id: event.slug, id: other_payee.hashid, amount: "250.00" }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not quote fees for a user who can't send payments" do
      create_session(create(:user), verified: true)
      expect_any_instance_of(LegalEntity::PayoutMethod).not_to receive(:estimated_fee_cents)

      get :transfer_fee, params: { event_id: event.slug, id: payee.hashid, amount: "250.00" }

      expect(response).to have_http_status(:redirect)
    end
  end

end
