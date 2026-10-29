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
        expect(Rails.error).not_to receive(:unexpected)

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
        expect(Rails.error).not_to receive(:unexpected)

        expect { described_class.new.run }
          .to have_enqueued_mail(ReimbursementMailer, :check_failed)
          .with(params: { reimbursement_payout_holding: payout_holding, reason: "Could not create Column account number" }, args: [])

        expect(payout_holding.reload).to be_failed
        expect(payout_holding.increase_check).to be_rejected
      end
    end
  end
end

RSpec.describe Reimbursement::PayoutHoldingService::Nightly do
  let!(:clearinghouse) do
    create(:event, :with_positive_balance, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
  end
  let(:user) { create(:user) }
  let(:report) do
    payout_method = user.personal_legal_entity.payout_methods.create!(details:)
    create(:reimbursement_report, user:, legal_entity_payout_method: payout_method)
  end

  before do
    system_user = create(:user, :make_admin)
    allow(User).to receive(:system_user).and_return(system_user)
    create(:governance_admin_transfer_limit, user: system_user)
    allow(ColumnService).to receive(:get).and_return({ "full_name" => "Test Bank", "country_code" => "DE" })
    allow(ColumnService).to receive(:post).and_return({
                                                        "id"             => "column_transfer",
                                                        "account_number" => "12345678",
                                                        "routing_number" => "021000021",
                                                        "status"         => "issued"
                                                      })
    allow(Rails.error).to receive(:unexpected)
  end

  let!(:payout_holding) do
    Reimbursement::PayoutHolding.create!(report:, amount_cents: 1234, aasm_state: "settled")
  end

  shared_examples "a reimbursement payout" do
    [Faraday::ServerError, Faraday::TimeoutError, Faraday::ConnectionFailed].each do |error_class|
      it "records #{error_class} and retries the same transfer after exactly 24 hours without emailing the recipient" do
        freeze_time
        allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(error_class.new("Unavailable"))

        expect { described_class.new.run }.not_to have_enqueued_mail(ReimbursementMailer, failure_mail)

        expect(payout_holding.reload).to be_failed
        expect(payout_holding.failure_reason).to eq("column_unavailable")
        expect(payout_holding.retry_at).to eq(24.hours.from_now)
        transfer = payout_holding.payout_transfer
        expect(transfer).to be_present
        expect(transfer).to be_pending

        allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })

        travel 24.hours - 1.second
        described_class.new.run
        expect(payout_holding.reload).to be_failed
        expect(transfer.reload.column_id).to be_nil

        travel 1.second
        expect { described_class.new.run }.not_to change(transfer.class, :count)
        expect(payout_holding.reload).to be_sent
        expect(payout_holding.failure_reason).to be_nil
        expect(payout_holding.retry_at).to be_nil
        expect(payout_holding.payout_transfer).to eq(transfer)
        expect(transfer.reload.column_id).to eq("column_transfer")
      end
    end

    it "waits another 24 hours if Column is still unavailable" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::ServerError.new("Unavailable"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 24.hours
      expect { described_class.new.run }.not_to have_enqueued_mail(ReimbursementMailer, failure_mail)

      expect(payout_holding.reload).to be_failed
      expect(payout_holding.retry_at).to eq(24.hours.from_now)
      expect(payout_holding.payout_transfer).to eq(transfer)
    end

    it "does not let an existing payout-info retry bypass the 24-hour delay" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::ServerError.new("Unavailable"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      payout_holding.mark_settled!
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      described_class.new.run

      expect(payout_holding.reload).to be_settled
      expect(transfer.reload.column_id).to be_nil

      travel 24.hours
      described_class.new.run
      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer).to eq(transfer)
    end

    it "requires reconciliation rather than retrying an ambiguous transfer after 29 days" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 29.days
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "duplicate_transfer" })
      described_class.new.run

      expect(payout_holding.reload).to be_failed
      expect(payout_holding.failure_reason).to eq("retry_window_expired")
      expect(payout_holding.retry_at).to be_nil
      described_class.new.run
      payout_holding.mark_settled!
      described_class.new.run
      expect(transfer.reload.column_id).to be_nil
      expect(payout_holding.reload).to be_failed
    end

    it "marks invalid payout details as failed and notifies the recipient" do
      error = Faraday::BadRequestError.new("Invalid payout details", status: 400, body: { "message" => "Invalid payout details" })
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(error)

      expect { described_class.new.run }.to have_enqueued_mail(ReimbursementMailer, failure_mail)

      expect(payout_holding.reload).to be_failed
      expect(payout_holding.payout_transfer).to be_rejected
      expect(payout_holding.retry_at).to be_nil

      travel 24.hours
      described_class.new.run
      expect(payout_holding.reload).to be_failed
    end

    it "creates a fresh transfer when a recipient-detail failure is explicitly retried" do
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::BadRequestError.new("Invalid details"))
      described_class.new.run
      rejected_transfer = payout_holding.reload.payout_transfer

      payout_holding.mark_settled!
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "corrected_transfer", "status" => "issued" })

      expect { described_class.new.run }.to change(rejected_transfer.class, :count).by(1)
      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer).not_to eq(rejected_transfer)
      expect(payout_holding.payout_transfer.column_id).to eq("corrected_transfer")
    end

    it "marks a successful payout as sent without sending a failure email" do
      expect { described_class.new.run }.not_to have_enqueued_mail(ReimbursementMailer, failure_mail)

      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer.column_id).to eq("column_transfer")
    end
  end

  context "with an ACH transfer" do
    let(:details) { LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021") }
    let(:endpoint) { "/transfers/ach" }
    let(:failure_mail) { :ach_failed }

    include_examples "a reimbursement payout"
  end

  context "with a wire" do
    let(:details) do
      LegalEntity::PayoutMethod::Wire.new(
        account_number: "DE89370400440532013000", bic_code: "DEUTDEDB", recipient_country: "DE",
        address_line1: "123 Main St", address_city: "Berlin", address_state: "Berlin", address_postal_code: "10115",
        recipient_information: {}
      )
    end
    let(:endpoint) { "/transfers/international-wire" }
    let(:failure_mail) { :wire_failed }

    include_examples "a reimbursement payout"
  end

  context "with a check" do
    let(:details) do
      LegalEntity::PayoutMethod::Check.new(
        address_line1: "123 Main St", address_city: "Burlington", address_state: "VT", address_postal_code: "05401"
      )
    end
    let(:endpoint) { "/transfers/checks/issue" }
    let(:failure_mail) { :check_failed }

    include_examples "a reimbursement payout"
  end
end
