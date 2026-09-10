# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoicesController do
  include SessionSupport

  let(:manager) { create(:user) }
  let(:event) { create(:event, organizers: [manager]) }
  let(:payee) { create(:payee, event:) }
  let(:position) { create(:payroll_position, payee:) }

  let(:attachment) { fixture_file_upload("files/receipt.png", "image/png") }

  def on_behalf_params(overrides = {})
    {
      event_id: event.slug,
      id: position.id,
      payroll_invoice: { name: "June engineering", amount: "100.00", file: [attachment] }.merge(overrides)
    }
  end

  before do
    Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
    # Onboarding requires several external steps; jump straight to the state
    # that gates on-behalf submission.
    position.update_column(:aasm_state, "onboarded")
    # Keep the balance check from short-circuiting the happy path.
    allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(1_000_00)
  end

  describe "POST #create_on_behalf" do
    context "as a manager" do
      before { create_session(manager, verified: true) }

      it "creates an approved invoice and its payment" do
        expect do
          post :create_on_behalf, params: on_behalf_params
        end.to change { position.invoices.count }.by(1)
                 .and change { payee.payments.count }.by(1)

        invoice = position.invoices.sole
        expect(invoice).to be_approved
        expect(invoice.reviewed_by).to eq(manager)
        expect(invoice.payment).to be_present
        expect(invoice.receipts.count).to eq(1)
        expect(response).to redirect_to(event_payroll_position_path(event_id: event.slug, id: position.id))
      end

      it "does not email managers to review an already-approved invoice" do
        expect do
          post :create_on_behalf, params: on_behalf_params
        end.not_to have_enqueued_mail(Payroll::InvoiceMailer, :submitted)
      end

      it "rejects a submission with no attachment and creates nothing" do
        post :create_on_behalf, params: on_behalf_params(file: [])

        expect(response).to have_http_status(:unprocessable_content)
        expect(position.invoices).to be_empty
        expect(Payment.count).to eq(0)
      end

      it "refuses to approve when the event can't cover the invoice" do
        allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(0)

        post :create_on_behalf, params: on_behalf_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:error]).to include("doesn't have enough money")
        expect(position.invoices).to be_empty
        expect(Payment.count).to eq(0)
      end

      it "does not allow invoicing a position that isn't onboarded" do
        position.update_column(:aasm_state, "onboarding")

        post :create_on_behalf, params: on_behalf_params

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(position.invoices).to be_empty
      end
    end

    context "as a contractor on the position (not a reviewer)" do
      let(:contractor) { create(:user) }

      before do
        create(:legal_entity_user, legal_entity: payee.legal_entity, user: contractor)
        create_session(contractor, verified: true)
      end

      it "is forbidden and creates nothing" do
        post :create_on_behalf, params: on_behalf_params

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(position.invoices).to be_empty
        expect(Payment.count).to eq(0)
      end
    end

    context "as an unrelated user" do
      before { create_session(create(:user), verified: true) }

      it "is forbidden and creates nothing" do
        post :create_on_behalf, params: on_behalf_params

        expect(flash[:error]).to eq("You are not authorized to perform this action.")
        expect(position.invoices).to be_empty
      end
    end
  end
end
