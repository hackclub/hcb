# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::PayoutHoldingService::Nightly do
  before do
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    create(:event, :with_positive_balance, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
  end

  let(:user) { create(:user) }
  let!(:payout_holding) do
    user.personal_legal_entity.payout_methods.create!(
      default: true,
      details: LegalEntity::PayoutMethod::Check.new(address_line1: "1 Main St", address_city: "New York", address_state: "NY", address_postal_code: "10001")
    )
    Reimbursement::PayoutHolding.create!(report: create(:reimbursement_report, user:), amount_cents: 130_00, aasm_state: :settled)
  end

  describe "check payouts" do
    context "when Column rejects the check" do
      before do
        error = Faraday::BadRequestError.new("the server responded with status 400", { status: 400, body: { "message" => "Invalid payee address" } })
        allow_any_instance_of(IncreaseCheck).to receive(:send_check!).and_raise(error)
      end

      it "fails the payout and tells the reimbursee Column's reason" do
        expect(Rails.error).to receive(:unexpected).with("[reimbursements / check issuing] Invalid payee address. report ID: #{payout_holding.report.id}")

        expect { described_class.new.run }
          .to have_enqueued_mail(ReimbursementMailer, :check_failed)
          .with(params: { reimbursement_payout_holding: payout_holding, reason: "Invalid payee address" }, args: [])

        expect(payout_holding.reload).to be_failed
        expect(payout_holding.increase_check).to be_rejected
      end
    end

    context "when something other than Column raises" do
      before do
        allow_any_instance_of(IncreaseCheck).to receive(:send_check!).and_raise(RuntimeError, "Could not create Column account number")
      end

      it "fails the payout and falls back to the error message" do
        expect(Rails.error).to receive(:unexpected).with("[reimbursements / check issuing] Could not create Column account number. report ID: #{payout_holding.report.id}")

        expect { described_class.new.run }
          .to have_enqueued_mail(ReimbursementMailer, :check_failed)
          .with(params: { reimbursement_payout_holding: payout_holding, reason: "Could not create Column account number" }, args: [])

        expect(payout_holding.reload).to be_failed
        expect(payout_holding.increase_check).to be_rejected
      end
    end
  end
end
