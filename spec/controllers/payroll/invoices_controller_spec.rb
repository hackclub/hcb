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
        expect(invoice.payment.receipts.count).to eq(1)
      end

      it "creates nothing when the balance won't cover it" do
        stub_balance(10_00)

        expect { post :create, params: invoice_params }
          .to have_enqueued_mail(Payroll::InvoiceMailer, :submitted).exactly(0).times

        expect(response).to have_http_status(:unprocessable_content)
        expect([Payroll::Invoice.count, Payment.count, Receipt.count]).to eq([0, 0, 0])
      end

      it "re-renders only the form inside its modal, without the validation prefix" do
        stub_balance(10_00)

        post :create, params: invoice_params

        expect(response.media_type).to eq(Mime[:turbo_stream])
        expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(position, :invoice_form)}"))
        expect(flash.now[:error]).to eq("Your organization doesn't have enough money to pay this invoice. Your balance is $10.00.")
      end

      it "rejects non-positive and non-numeric amounts" do
        stub_balance(100_00)

        %w[0 -50.00 abc].each do |amount|
          post :create, params: invoice_params(amount:)

          expect(response).to have_http_status(:unprocessable_content)
          expect(flash.now[:error]).to eq("Amount must be greater than 0")
          expect([Payroll::Invoice.count, Payment.count]).to eq([0, 0])
        end
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

    context "as an organizer who isn't a manager" do
      before do
        member = create(:user)
        create(:organizer_position, event:, user: member, role: :member)
        create_session(member, verified: true)
        stub_balance(100_00)
      end

      it "can't upload and approve an invoice on the contractor's behalf" do
        expect { post :create, params: invoice_params }.not_to change(Payroll::Invoice, :count)
      end
    end
  end

  describe "POST #approve" do
    let(:invoice) { position.invoices.create!(name: "Engineering hours", amount_cents: 50_00, currency: position.currency) }

    def approve!
      post :approve, params: { event_id: event.slug, id: invoice.id }
    end

    context "as an organizer" do
      before { create_session(organizer, verified: true) }

      it "pays an invoice only once when approved twice" do
        stub_balance(100_00)

        expect { 2.times { approve! } }.to change(Payment, :count).by(1)
        expect(flash[:error]).to eq("This invoice has already been reviewed.")
      end

      it "leaves the invoice reviewable when the balance won't cover it" do
        stub_balance(10_00)

        expect { approve! }.not_to change(Payment, :count)
        expect(invoice.reload).to be_submitted
        expect(flash[:error]).to include("Your balance is $10.00")
      end
    end

    context "as an organizer who is also the contractor" do
      before do
        create(:legal_entity_user, legal_entity:, user: organizer)
        create_session(organizer, verified: true)
        stub_balance(100_00)
      end

      it "can't approve their own invoice" do
        expect { approve! }.not_to change(Payment, :count)
        expect(invoice.reload).to be_submitted
      end

      it "still can't once the position is no longer active" do
        position.update_column(:aasm_state, "terminated")

        expect { approve! }.not_to change(Payment, :count)
        expect(invoice.reload).to be_submitted
      end
    end
  end

  describe "POST #reject" do
    before { create_session(organizer, verified: true) }

    # Invoices created before amounts had to be positive must still be reviewable.
    it "rejects a legacy invoice with a non-positive amount" do
      invoice = position.invoices.create!(name: "Engineering hours", amount_cents: 50_00, currency: position.currency)
      invoice.update_column(:amount_cents, 0)

      post :reject, params: { event_id: event.slug, id: invoice.id }

      expect(invoice.reload).to be_rejected
      expect(invoice.reviewed_by).to eq(organizer)
    end
  end
end
