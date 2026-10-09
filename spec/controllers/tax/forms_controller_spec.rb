# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::FormsController do
  include SessionSupport

  describe "create" do
    def authorized_legal_entity
      user = create(:user)
      create_session(user, verified: true)
      user.personal_legal_entity
    end

    it "refuses to start a tax form when nothing requires one" do
      legal_entity = authorized_legal_entity

      expect {
        post :create, params: { legal_entity_id: legal_entity.hashid }
      }.not_to(change { legal_entity.tax_forms.count })

      expect(response).to redirect_to(legal_entity_path(legal_entity))
      expect(flash[:error]).to eq "You don't need to submit a tax form right now"
    end

    it "starts a tax form when a pending payment requires one" do
      legal_entity = authorized_legal_entity
      payee = create(:payee, legal_entity:)
      allow(PaymentMailer).to receive(:with).and_return(double.as_null_object)
      create(:payment, payee:, amount_cents: 100_000, classification: :general_services)

      expect {
        post :create, params: { legal_entity_id: legal_entity.hashid }
      }.to change { legal_entity.tax_forms.count }.by(1)

      expect(response).to redirect_to(tax_form_path(legal_entity.tax_forms.last))
    end

    it "starts a tax form for a contractor mid-onboarding, even with no qualifying payment" do
      legal_entity = authorized_legal_entity
      payee = create(:payee, legal_entity:)
      create(:payroll_position, payee:, aasm_state: "onboarding")

      expect {
        post :create, params: { legal_entity_id: legal_entity.hashid }
      }.to change { legal_entity.tax_forms.count }.by(1)
    end
  end

  describe "electronic consent" do
    render_views

    let(:user) { create(:user) }
    let(:legal_entity) { user.personal_legal_entity }
    let(:form) { create(:tax_form, :sent, legal_entity:) }

    before { create_session(user, verified: true) }

    it "shows the consent page" do
      get :electronic_consent, params: { id: form.hashid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Consent to electronic delivery")
    end

    it "records consent" do
      freeze_time do
        post :update_electronic_consent, params: { id: form.hashid, electronic_consent: "true" }

        expect(response).to redirect_to(completed_tax_form_path(form))
        expect(legal_entity.reload.electronic_consent).to be(true)
        expect(legal_entity.electronic_consent_at).to eq(Time.current)
      end
    end

    it "records a refusal" do
      post :update_electronic_consent, params: { id: form.hashid, electronic_consent: "false" }

      expect(response).to redirect_to(completed_tax_form_path(form))
      expect(legal_entity.reload.electronic_consent).to be(false)
      expect(legal_entity.electronic_consent_at).to be_present
    end

    it "doesn't let other users consent on the recipient's behalf" do
      create_session(create(:user), verified: true)

      post :update_electronic_consent, params: { id: form.hashid, electronic_consent: "false" }

      expect(legal_entity.reload.electronic_consent).to be_nil
    end
  end
end
