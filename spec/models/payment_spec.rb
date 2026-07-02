# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment, type: :model do
  let(:payee) { create(:payee) }
  subject(:payment) { build(:payment, payee:) }

  before do
    # Suppress all PaymentMailer deliveries by default so that after_create
    # callbacks don't interfere with unrelated tests. Tests that assert mailer
    # behaviour override this stub in the test body.
    allow(PaymentMailer).to receive(:with).and_return(double.as_null_object)
    stub_legal_entity(payment, complete: false, payout_method: nil)
  end

  def stub_legal_entity(payment, complete:, payout_method:)
    legal_entity = double("LegalEntity", payable?: complete, default_payout_method: payout_method).as_null_object
    # Stub directly on payment so the stub survives with_lock's reload (which
    # resets association caches). has_one :through issues SQL, not a Ruby
    # delegation, so stubbing payee.legal_entity won't intercept it.
    allow(payment).to receive(:legal_entity).and_return(legal_entity)
  end

  describe "state machine" do
    describe "initial state" do
      it "starts as pending_legal_entity" do
        expect(payment).to be_pending_legal_entity
      end
    end

    describe "#mark_sent!" do
      before do
        payment.save!
        payment.update_columns(aasm_state: "under_review")
      end

      it "delivers the sent mailer" do
        mail = double("mail", deliver_later: true)
        allow(PaymentMailer).to receive_message_chain(:with, :sent).and_return(mail)
        payment.mark_sent!
        expect(mail).to have_received(:deliver_later)
      end
    end

    describe "#mark_rejected!" do
      before do
        payment.save!
        payment.update_columns(aasm_state: "under_review")
      end
    end

  end

  describe "after_create" do
    let(:payee) { create(:payee) }

    def create_payment_with_legal_entity(complete:, payout_method:)
      payment = build(:payment, payee:)
      stub_legal_entity(payment, complete:, payout_method:)
      payment.save!
      payment
    end

    context "when the legal entity is complete and has a default payout method" do
      let(:payout_method) { create(:legal_entity_payout_method) }

      before do
        allow_any_instance_of(Payment::Attempt).to receive(:create_transfer!)
      end

      it "creates a Payment::Attempt with that payout method" do
        payment = create_payment_with_legal_entity(complete: true, payout_method:)
        expect(payment.attempts.count).to eq 1
        expect(payment.attempts.first.payout_method).to eq payout_method
      end

      it "does not send any mailer" do
        expect(PaymentMailer).not_to receive(:with)
        create_payment_with_legal_entity(complete: true, payout_method:)
      end
    end

    context "when the legal entity is complete but has no default payout method" do
      it "does not create any attempt" do
        payment = create_payment_with_legal_entity(complete: true, payout_method: nil)
        expect(payment.attempts).to be_empty
      end

      it "delivers the missing_payout_method mailer" do
        mail = double("mail", deliver_later: true)
        allow(PaymentMailer).to receive_message_chain(:with, :missing_payout_method).and_return(mail)
        create_payment_with_legal_entity(complete: true, payout_method: nil)
        expect(mail).to have_received(:deliver_later)
      end
    end

    context "when the legal entity is not complete" do
      it "does not create any attempt" do
        payment = create_payment_with_legal_entity(complete: false, payout_method: nil)
        expect(payment.attempts).to be_empty
      end

      it "delivers the missing_tax_information mailer" do
        mail = double("mail", deliver_later: true)
        allow(PaymentMailer).to receive_message_chain(:with, :missing_tax_information).and_return(mail)
        create_payment_with_legal_entity(complete: false, payout_method: nil)
        expect(mail).to have_received(:deliver_later)
      end
    end
  end

  describe "Tax::Form integration" do
    # Full-stack: real DB objects, no doubles. Verifies that marking a tax form
    # completed triggers the correct payment-processing path.

    # :person avoids the LegalEntity after_create :send_tax_form! hook (which
    # hits an external API for business entities).
    let(:legal_entity) { create(:legal_entity, :person) }
    let(:payee)        { create(:payee, legal_entity:) }

    # Form is in :sent state with TIN matching already verified — payable? will
    # pass once the form transitions to :completed.
    let!(:tax_form) do
      legal_entity.tax_forms.create!(
        external_service: :taxbandits,
        aasm_state: "sent",
        taxbandits_tin_matching_status: "success"
      )
    end

    # The payment's after_create sees an unpayable entity (form is :sent, not
    # :completed) and would send the missing_tax_information mailer. Suppress it
    # globally; individual tests override when asserting specific mailer calls.
    before { allow(PaymentMailer).to receive(:with).and_return(double.as_null_object) }

    let!(:payment) { create(:payment, payee:) }

    context "when the tax form is completed and the entity becomes payable" do
      context "with a default payout method" do
        let!(:payout_method) { create(:legal_entity_payout_method, legal_entity:, default: true) }

        before { allow_any_instance_of(Payment::Attempt).to receive(:create_transfer!) }

        it "creates a payment attempt" do
          expect { tax_form.mark_completed! }.to change { payment.attempts.reload.count }.by(1)
        end

        it "uses the default payout method for the attempt" do
          tax_form.mark_completed!
          expect(payment.attempts.reload.last.payout_method).to eq payout_method
        end
      end

      context "without a default payout method" do
        it "sends the missing_payout_method mailer" do
          mail = double("mail", deliver_later: true)
          allow(PaymentMailer).to receive_message_chain(:with, :missing_payout_method).and_return(mail)
          tax_form.mark_completed!
          expect(mail).to have_received(:deliver_later)
        end

        it "does not create a payment attempt" do
          expect { tax_form.mark_completed! }.not_to(change { payment.attempts.count })
        end
      end
    end

    context "when the tax form is completed but the entity is not payable (TIN banned)" do
      before { legal_entity.update!(banned_reason: "confirmed fraud") }

      it "does not create any payment attempt" do
        expect { tax_form.mark_completed! }.not_to(change { payment.attempts.count })
      end

      it "does not send any payment-related mailer" do
        expect(PaymentMailer).not_to receive(:with)
        tax_form.mark_completed!
      end
    end
  end

  describe "#retry!" do
    let(:payout_method) { create(:legal_entity_payout_method) }
    let(:payment) do
      p = build(:payment, payee: create(:payee))
      # Save with complete: false so after_create sends a mailer (suppressed by
      # the outer before) rather than creating an attempt that would conflict
      # with the factory-created attempts set up in each context.
      stub_legal_entity(p, complete: false, payout_method: nil)
      p.save!
      p
    end

    before do
      allow_any_instance_of(Payment::Attempt).to receive(:create_transfer!)
      stub_legal_entity(payment, complete: true, payout_method:)
    end

    context "when all previous attempts have failed" do
      before { create(:payment_attempt, payment:, aasm_state: "failed") }

      it "creates a new attempt" do
        expect { payment.retry! }.to change { payment.attempts.count }.by(1)
      end

      it "uses the default payout method for the new attempt" do
        payment.retry!
        expect(payment.attempts.last.payout_method).to eq payout_method
      end

      it "runs inside a lock" do
        expect(payment).to receive(:with_lock).and_call_original
        payment.retry!
      end
    end

    context "when the payment has been rejected" do
      before { payment.update_columns(aasm_state: "rejected") }

      it "raises ArgumentError" do
        expect { payment.retry! }.to raise_error(ArgumentError, /rejected/)
      end
    end

    context "when at least one attempt has not failed" do
      before { create(:payment_attempt, payment:, aasm_state: "pending") }

      it "raises ArgumentError" do
        expect { payment.retry! }.to raise_error(ArgumentError, /all attempts must have failed/)
      end
    end

    context "when there is no default payout method" do
      before do
        create(:payment_attempt, payment:, aasm_state: "failed")
        stub_legal_entity(payment, complete: true, payout_method: nil)
      end

      it "raises ArgumentError" do
        expect { payment.retry! }.to raise_error(ArgumentError, /no default payout method/)
      end
    end
  end

end
