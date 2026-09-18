# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::InvoicesController do
  include SessionSupport

  let(:organizer) { create(:user) }
  let(:event) { create(:event, organizers: [organizer]) }
  let(:legal_entity) { create(:legal_entity) }
  let(:payee) { create(:payee, event:, legal_entity:) }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }

  before do
    Flipper.enable(:payments_contractors_refresh_2026_06_26, event)
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
  end

  def invoice_params(**overrides)
    {
      payroll_position_id: position.id,
      payroll_invoice: {
        name: "Engineering hours",
        amount: "50.00",
        file: [fixture_file_upload("receipt.png", "image/png")]
      }.merge(overrides)
    }
  end

  def stub_balance(cents)
    allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(cents)
  end

  describe "POST #create" do
    context "as an organizer uploading on the contractor's behalf" do
      before { create_session(organizer, verified: true) }

      it "approves and pays the invoice without emailing the manager" do
        stub_balance(100_00)

        expect { post :create, params: invoice_params }
          .to change(Payment, :count).by(1)
          .and have_enqueued_mail(Payroll::InvoiceMailer, :submitted).exactly(0).times

        invoice = Payroll::Invoice.sole
        expect(invoice).to be_approved
        expect(invoice.reviewed_by).to eq(organizer)
        expect(invoice.payment.amount_cents).to eq(50_00)
      end

      it "leaves the invoice for manual review when the balance won't cover it" do
        stub_balance(10_00)

        expect { post :create, params: invoice_params }
          .to have_enqueued_mail(Payroll::InvoiceMailer, :submitted)
          .and change(Payroll::Invoice, :count).by(1)

        expect(Payment.count).to eq(0)
        expect(Payroll::Invoice.sole).to be_submitted
      end

      it "rejects an invoice with no attachment" do
        expect { post :create, params: invoice_params(file: []) }.not_to change(Payroll::Invoice, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as the contractor themselves" do
      before do
        create(:legal_entity_user, legal_entity:, user: organizer)
        create_session(organizer, verified: true)
      end

      # An organizer who is also the contractor must not be able to approve
      # their own pay by routing it through this endpoint.
      it "never auto-approves, even for a user who could otherwise review" do
        stub_balance(100_00)

        expect { post :create, params: invoice_params }.not_to change(Payment, :count)

        expect(Payroll::Invoice.sole).to be_submitted
      end
    end

    context "as a user with no permissions on the event" do
      before { create_session(create(:user), verified: true) }

      it "refuses to create the invoice" do
        expect { post :create, params: invoice_params }.not_to change(Payroll::Invoice, :count)
      end
    end
  end
end
