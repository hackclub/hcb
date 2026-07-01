# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment::Attempt, type: :model do
  subject(:attempt) { build(:payment_attempt) }

  describe "#other_attempts_failed validation" do
    let(:payment) { create(:payment) }

    context "when all sibling attempts are failed" do
      before { create(:payment_attempt, payment:, aasm_state: "failed") }

      it "allows creating a new attempt" do
        new_attempt = build(:payment_attempt, payment:)
        expect(new_attempt).to be_valid
      end
    end

    context "when a sibling attempt is not failed" do
      before { create(:payment_attempt, payment:, aasm_state: "pending") }

      it "is invalid" do
        new_attempt = build(:payment_attempt, payment:)
        expect(new_attempt).not_to be_valid
        expect(new_attempt.errors[:base]).to include(/all other attempts for this payment must be failed/)
      end
    end

    context "on the very first attempt for a payment" do
      it "is valid (no siblings to check)" do
        attempt = build(:payment_attempt, payment:)
        expect(attempt).to be_valid
      end
    end
  end

  describe "#failed_successful_attempts_frozen validation" do
    context "when updating a failed attempt without changing state" do
      let(:attempt) { create(:payment_attempt, aasm_state: "failed") }

      it "is invalid" do
        attempt.valid?(:update)
        expect(attempt.errors[:base]).to include(/failed, successful, rejected, or canceled payment attempts cannot be updated/)
      end
    end

    context "when transitioning a sent attempt to failed" do
      let(:attempt) { create(:payment_attempt, aasm_state: "sent") }

      it "is valid because aasm_state is changing" do
        attempt.aasm_state = "failed"
        expect(attempt.valid?(:update)).to be true
      end
    end

    context "when updating a successful attempt without changing state" do
      let(:attempt) { create(:payment_attempt, aasm_state: "successful") }

      it "is invalid" do
        attempt.valid?(:update)
        expect(attempt.errors[:base]).to include(/failed, successful, rejected, or canceled payment attempts cannot be updated/)
      end
    end
  end

  describe "AASM" do
    describe "#mark_under_review!" do
      it "requires a payout to be present" do
        attempt.save!
        attempt.payout = nil
        expect { attempt.mark_under_review! }.to raise_error(AASM::InvalidTransition)
      end

      it "transitions to under_review when payout is set" do
        attempt.save!
        allow(attempt).to receive(:payout).and_return(double(present?: true, class: AchTransfer))
        attempt.mark_under_review!
        expect(attempt).to be_under_review
      end

      it "calls mark_under_review! on the parent payment" do
        attempt.save!
        allow(attempt).to receive(:payout).and_return(double(present?: true, class: AchTransfer))
        expect(attempt.payment).to receive(:mark_under_review!)
        attempt.mark_under_review!
      end
    end

    describe "#mark_sent!" do
      before do
        attempt.save!
        attempt.update_columns(aasm_state: "under_review")
        # The mark_sent after block calls payment.mark_sent!; stub it so we
        # don't have to put the payment into under_review state as well.
        allow(attempt.payment).to receive(:mark_sent!)
      end

      it "transitions to sent" do
        attempt.mark_sent!
        expect(attempt).to be_sent
      end

      it "calls mark_sent! on the parent payment" do
        expect(attempt.payment).to receive(:mark_sent!)
        attempt.mark_sent!
      end
    end

    describe "#mark_successful!" do
      before do
        attempt.save!
        attempt.update_columns(aasm_state: "sent")
        allow(attempt.payment).to receive(:mark_successful!)
      end

      it "transitions to successful" do
        attempt.mark_successful!
        expect(attempt).to be_successful
      end

      it "calls mark_successful! on the parent payment" do
        expect(attempt.payment).to receive(:mark_successful!)
        attempt.mark_successful!
      end
    end

    describe "#mark_failed!" do
      let(:attempt) { create(:payment_attempt, aasm_state: "sent") }
      let(:payout)  { double("payout", class: AchTransfer) }
      let(:receipt) { double("receipt") }

      before do
        allow(attempt).to receive(:payout).and_return(payout)
        allow(payout).to receive(:receipts).and_return([receipt])
        allow(receipt).to receive(:update!)
        # Suppress both mailer chains (failed_creator + failed_payee) by default.
        allow(Payment::AttemptMailer).to receive(:with).and_return(double.as_null_object)
      end

      it "transitions to failed" do
        attempt.mark_failed!
        expect(attempt).to be_failed
      end

      it "delivers the failed_creator mailer" do
        mail = double("mail", deliver_later: true)
        mailer_double = double.as_null_object
        allow(mailer_double).to receive(:failed_creator).and_return(mail)
        allow(Payment::AttemptMailer).to receive(:with).and_return(mailer_double)
        attempt.mark_failed!
        expect(mail).to have_received(:deliver_later)
      end

      it "delivers the failed_payee mailer" do
        mail = double("mail", deliver_later: true)
        mailer_double = double.as_null_object
        allow(mailer_double).to receive(:failed_payee).and_return(mail)
        allow(Payment::AttemptMailer).to receive(:with).and_return(mailer_double)
        attempt.mark_failed!
        expect(mail).to have_received(:deliver_later)
      end

      it "accepts an optional reason" do
        expect { attempt.mark_failed!(reason: "Receipt is insufficient for this payment") }.not_to raise_error
      end
    end
  end

  describe "#transfer_matches_payout_method validation" do
    {
      check_payout_method_details: IncreaseCheck,
      ach_transfer_payout_method_details: AchTransfer,
      wire_payout_method_details: Wire,
      wise_transfer_payout_method_details: WiseTransfer,
    }.each do |details_factory, payout_class|
      context "with #{details_factory} and the matching #{payout_class} payout" do
        it "is valid" do
          payout_method = build(:legal_entity_payout_method, details: build(details_factory))
          attempt = build(:payment_attempt, payout_method:)
          allow(attempt).to receive(:payout).and_return(double("payout", present?: true, class: payout_class))
          attempt.valid?
          expect(attempt.errors[:base]).not_to include("transfer type must match payout method")
        end
      end
    end

    context "when the payout class does not match the payout method" do
      it "adds an error" do
        payout_method = build(:legal_entity_payout_method, details: build(:check_payout_method_details))
        attempt = build(:payment_attempt, payout_method:)
        allow(attempt).to receive(:payout).and_return(double("payout", present?: true, class: AchTransfer))
        attempt.valid?
        expect(attempt.errors[:base]).to include("transfer type must match payout method")
      end
    end

    context "when payout is absent" do
      it "is valid (skips the check)" do
        payout_method = build(:legal_entity_payout_method, details: build(:check_payout_method_details))
        attempt = build(:payment_attempt, payout_method:)
        allow(attempt).to receive(:payout).and_return(nil)
        attempt.valid?
        expect(attempt.errors[:base]).not_to include("transfer type must match payout method")
      end
    end
  end

  describe "after_create create_transfer!" do
    # These tests exercise the branching on payout_method.details type.
    # We call create_transfer! directly to avoid triggering Rails' save
    # machinery on association doubles. We stub `safely` to be a no-op so
    # external-service calls inside each branch are skipped.

    def build_attempt_with_payout_method(payout_method)
      attempt = build(:payment_attempt)
      # Override the factory's create_transfer! stub so the real method runs
      # when called directly via attempt.send(:create_transfer!).
      allow(attempt).to receive(:create_transfer!).and_call_original
      payment_double = double("payment").as_null_object
      allow(payment_double).to receive_message_chain(:legal_entity, :default_payout_method).and_return(payout_method)
      allow(attempt).to receive(:payment).and_return(payment_double)
      # Make safely a no-op so external-service calls inside each branch are
      # skipped; we only care that mark_under_review! is called at the end.
      allow(attempt).to receive(:safely)
      attempt
    end

    shared_examples "a transfer creator" do |details_class|
      it "calls mark_under_review! after creating the transfer" do
        payout_method = build(:legal_entity_payout_method, details: build(details_class))
        attempt = build_attempt_with_payout_method(payout_method)
        expect(attempt).to receive(:mark_under_review!)
        attempt.send(:create_transfer!)
      end
    end

    context "with a Check payout method" do
      include_examples "a transfer creator", :check_payout_method_details
    end

    context "with an AchTransfer payout method" do
      include_examples "a transfer creator", :ach_transfer_payout_method_details
    end

    context "with a Wire payout method" do
      include_examples "a transfer creator", :wire_payout_method_details
    end

    context "with a WiseTransfer payout method" do
      include_examples "a transfer creator", :wise_transfer_payout_method_details
    end

    context "with an unsupported payout method type" do
      it "raises ArgumentError" do
        # Pass a real payout_method to the factory, then stub details to return
        # an unrecognised type — avoids passing an RSpec double to FactoryBot.
        payout_method = build(:legal_entity_payout_method)
        allow(payout_method).to receive(:details).and_return(double("UnknownMethod"))
        attempt = build_attempt_with_payout_method(payout_method)
        expect { attempt.send(:create_transfer!) }.to raise_error(ArgumentError, /unsupported payout method/)
      end
    end

    it "calls Receipt.reupload to transfer payment receipts to the new transfer's hcb_code" do
      payout_method = build(:legal_entity_payout_method, details: build(:check_payout_method_details))
      attempt = build(:payment_attempt)
      allow(attempt).to receive(:create_transfer!).and_call_original
      allow(attempt).to receive(:safely).and_yield
      allow(attempt).to receive(:save!)
      allow(attempt).to receive(:mark_under_review!)
      allow(attempt).to receive(:payout=)

      payee_dbl = double("payee", display_name: "Alice", email: "alice@example.com")
      hcb_code  = double("hcb_code")
      check     = double("check", save!: nil, local_hcb_code: hcb_code)
      checks_rel = double("checks_rel", build: check)
      event_dbl  = double("event", increase_checks: checks_rel)
      payment_dbl = double("payment",
                           payee: payee_dbl,
                           event: event_dbl,
                           purpose: "Test purpose",
                           estimate_usd_amount_cents: 10_000,
                           creator: double("creator"))
      allow(payment_dbl).to receive_message_chain(:legal_entity, :default_payout_method).and_return(payout_method)
      allow(attempt).to receive(:payment).and_return(payment_dbl)

      allow(User).to receive(:system_user).and_return(double("system_user"))
      expect(Receipt).to receive(:reupload).with(old_receiptable: payment_dbl, new_receiptable: hcb_code)
      attempt.send(:create_transfer!)
    end
  end
end
