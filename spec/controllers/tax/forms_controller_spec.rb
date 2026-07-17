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
      create(:payment, payee:, amount_cents: 100_000, tax_reportable: true)

      expect {
        post :create, params: { legal_entity_id: legal_entity.hashid }
      }.to change { legal_entity.tax_forms.count }.by(1)

      expect(response).to redirect_to(tax_form_path(legal_entity.tax_forms.last))
    end

    it "does not start a tax form when the only pending payment is below the minimum" do
      legal_entity = authorized_legal_entity
      payee = create(:payee, legal_entity:)
      allow(PaymentMailer).to receive(:with).and_return(double.as_null_object)
      create(:payment, payee:, amount_cents: 100, tax_reportable: true)

      expect {
        post :create, params: { legal_entity_id: legal_entity.hashid }
      }.not_to(change { legal_entity.tax_forms.count })

      expect(flash[:error]).to eq "You don't need to submit a tax form right now"
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
end
