# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::PayoutHoldingService::Nightly, type: :request do
  let!(:clearinghouse) do
    create(:event, :with_positive_balance, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
  end
  let(:user) { create(:user) }
  let(:status_endpoint) { "#{endpoint.delete_suffix('/issue')}/column_transfer" }
  let(:report) do
    payout_method = user.personal_legal_entity.payout_methods.create!(details:)
    create(:reimbursement_report, user:, legal_entity_payout_method: payout_method, aasm_state: :reimbursed)
  end

  def deliver_column_webhook(transfer, status)
    secret = "test_reimbursement_webhook_secret"
    allow(Credentials).to receive(:fetch).and_call_original
    allow(Credentials).to receive(:fetch).with(:COLUMN, ColumnService::ENVIRONMENT, :WEBHOOK_SECRET).and_return(secret)
    event_type = case transfer
                 when AchTransfer then "ach.outgoing_transfer.#{status}"
                 when Wire then "swift.outgoing_transfer.returned"
                 when IncreaseCheck then "check.incoming_debit.#{status}"
                 end
    remote = { "id" => "column_transfer", "status" => status, "return_details" => [{ "description" => "Returned by bank" }], "return_reason" => "Returned by bank" }
    body = { type: event_type, data: remote }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    post "/webhooks/column", params: body, headers: { "Column-Signature" => signature, "Content-Type" => "application/json" }
    expect(response).to have_http_status(:ok)
    remote
  end

  before do
    system_user = create(:user, :make_admin)
    allow(User).to receive(:system_user).and_return(system_user)
    create(:governance_admin_transfer_limit, user: system_user)
    allow(ColumnService).to receive(:get).and_return({ "full_name" => "Test Bank", "country_code" => "DE" })
    allow(ColumnService).to receive(:get).with(status_endpoint).and_return({ "id" => "column_transfer", "status" => remote_status })
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

  shared_examples "a reimbursement payout" do |return_statuses|
    let(:replacement) do
      if details.is_a?(LegalEntity::PayoutMethod::AchTransfer)
        {
          details_type: "LegalEntity::PayoutMethod::Check",
          details_attrs: { address_line1: "456 Main St", address_city: "Burlington", address_state: "VT", address_postal_code: "05401" }
        }
      else
        {
          details_type: "LegalEntity::PayoutMethod::AchTransfer",
          details_attrs: { account_number: "87654321", routing_number: "021000021" }
        }
      end
    end

    it "keeps an unresolved payment pinned when the recipient changes payout type" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer
      original_method = report.reload.payout_method

      service = LegalEntity::PayoutMethodService::Update.new(legal_entity: user.personal_legal_entity, **replacement)
      service.run!

      expect(user.reload.default_payout_method).to eq(service.payout_method)
      expect(report.reload.payout_method).to eq(original_method)
      expect(payout_holding.reload).to be_failed

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer).to eq(transfer)
      expect(transfer.reload.column_id).to eq("column_transfer")
    end

    it "recovers the original transfer even if the report was repointed by another caller" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer
      service = LegalEntity::PayoutMethodService::Update.new(legal_entity: user.personal_legal_entity, **replacement)
      service.run!
      report.update!(legal_entity_payout_method: service.payout_method)

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer).to eq(transfer)
      expect(transfer.reload.column_id).to eq("column_transfer")
    end

    it "requires reconciliation if an administrator locally rejects an unresolved transfer" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer
      transfer.mark_rejected!

      travel 24.hours
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.failure_reason).to eq("reconciliation_required")
      expect(payout_holding.retry_at).to be_nil
      expect(payout_holding.payout_transfer).to eq(transfer)

      payout_holding.mark_settled!
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_failed
    end

    return_statuses.each do |status|
      it "reconciles #{status} after a return webhook arrives before the Column ID is recovered" do
        freeze_time
        allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
        described_class.new.run
        transfer = payout_holding.reload.payout_transfer
        expect(transfer.column_id).to be_nil

        remote = deliver_column_webhook(transfer, status)

        travel 24.hours
        allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
        allow(ColumnService).to receive(:get).with(status_endpoint).and_return(remote)
        expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
        expect(payout_holding.reload).to be_failed
        expect(payout_holding.retry_at).to be_nil
        expect(transfer.reload.column_id).to eq("column_transfer")
        if transfer.is_a?(IncreaseCheck)
          expect(transfer.column_status).to eq(status)
        else
          expect(transfer).to be_failed
        end
        described_class.new.run
        expect(payout_holding.reload).to be_failed
      end
    end

    it "does not mark a recovered payment sent when Column's current status cannot be fetched" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      allow(ColumnService).to receive(:get).with(status_endpoint).and_raise(Faraday::ServerError.new("Unavailable"))
      described_class.new.run
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.retry_at).to eq(24.hours.from_now)
      expect(transfer.reload.column_id).to eq("column_transfer")

      travel 24.hours
      allow(ColumnService).to receive(:get).with(status_endpoint).and_return({ "id" => "column_transfer", "status" => remote_status })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer).to eq(transfer)
    end

    it "accepts a bank return webhook while recovery has already failed" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      allow(ColumnService).to receive(:get).with(status_endpoint).and_raise(Faraday::ServerError.new("Unavailable"))
      described_class.new.run
      expect(payout_holding.reload).to be_failed
      expect(transfer.reload.column_id).to eq("column_transfer")

      deliver_column_webhook(transfer, return_statuses.first)
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.retry_at).to be_nil
      expect(payout_holding.failure_reason).to be_nil
      if transfer.is_a?(IncreaseCheck)
        expect(transfer.reload.column_status).to eq(return_statuses.first)
      else
        expect(transfer.reload).to be_failed
      end
      travel 24.hours
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
    end

    it "requires reconciliation rather than assuming an unknown remote status means sent" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      allow(ColumnService).to receive(:get).with(status_endpoint).and_return({ "id" => "column_transfer", "status" => "unrecognized_status" })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.failure_reason).to eq("reconciliation_required")
      expect(payout_holding.retry_at).to be_nil
      expect(payout_holding.payout_transfer).to eq(transfer)
    end

    it "does not reinterpret a bad request during recovery as a confirmed recipient-detail failure" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      transfer = payout_holding.reload.payout_transfer

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::BadRequestError.new("Recovery rejected"))
      expect { described_class.new.run }.not_to have_enqueued_mail(ReimbursementMailer, failure_mail)
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.failure_reason).to eq("reconciliation_required")
      expect(payout_holding.retry_at).to be_nil
      expect(payout_holding.payout_transfer).to eq(transfer)
      expect(transfer.reload).to be_pending
    end

    [Faraday::ServerError, Faraday::TimeoutError, Faraday::ConnectionFailed,
     Faraday::SSLError, Faraday::ParsingError, Faraday::ClientError].each do |error_class|
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

    it "requires reconciliation rather than retrying an ambiguous transfer after a parsing error and 29 days" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::ParsingError.new("Unreadable response"))
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

    it "recovers the replacement payout after changing type following a confirmed rejection" do
      freeze_time
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::BadRequestError.new("Invalid details"))
      described_class.new.run
      rejected_transfer = payout_holding.reload.payout_transfer
      expect(rejected_transfer).to be_rejected

      # The old attempt must not determine the replacement's retry deadline.
      travel 29.days
      service = LegalEntity::PayoutMethodService::Update.new(legal_entity: user.personal_legal_entity, **replacement)
      service.run!
      replacement_endpoint = replacement[:details_type].end_with?("Check") ? "/transfers/checks/issue" : "/transfers/ach"
      replacement_status = replacement[:details_type].end_with?("Check") ? "issued" : "SUBMITTED"
      allow(ColumnService).to receive(:post).with(replacement_endpoint, anything).and_raise(Faraday::TimeoutError.new("Accepted but response lost"))
      described_class.new.run
      expect(payout_holding.reload.failure_reason).to eq("column_unavailable")

      travel 24.hours
      allow(ColumnService).to receive(:post).with(replacement_endpoint, anything).and_return({ "id" => "replacement_transfer", "status" => "issued" })
      allow(ColumnService).to receive(:get).with("#{replacement_endpoint.delete_suffix('/issue')}/replacement_transfer").and_return({ "id" => "replacement_transfer", "status" => replacement_status })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })

      expect(payout_holding.reload).to be_sent
      expect(payout_holding.failure_reason).to be_nil
      expect(payout_holding.retry_at).to be_nil
      expect(payout_holding.payout_transfer).not_to eq(rejected_transfer)
      expect(payout_holding.payout_transfer.column_id).to eq("replacement_transfer")
      expect(rejected_transfer.reload).to be_rejected
    end

    it "recovers the current payout instead of superseded PayPal and Wise transfers" do
      freeze_time
      paypal_transfer = PaypalTransfer.new(
        event: clearinghouse, user:, amount_cents: 1234, memo: "Previous payout", payment_for: "Reimbursement",
        recipient_name: user.full_name, recipient_email: user.email, aasm_state: "failed"
      )
      # Historical PayPal transfers predate the current creation-only ban.
      paypal_transfer.save!(validate: false)
      wise_transfer = WiseTransfer.create!(
        event: clearinghouse, user:, amount_cents: 1234, quoted_usd_amount_cents: 1234, currency: "CAD",
        payment_for: "Reimbursement", recipient_name: user.full_name, recipient_email: user.email,
        recipient_country: :CA, aasm_state: "failed"
      )
      payout_holding.update!(paypal_transfer:, wise_transfer:)

      allow(ColumnService).to receive(:post).with(endpoint, anything).and_raise(Faraday::TimeoutError.new("Response lost"))
      described_class.new.run
      expect(payout_holding.reload.failure_reason).to eq("column_unavailable")

      travel 24.hours
      allow(ColumnService).to receive(:post).with(endpoint, anything).and_return({ "id" => "column_transfer", "status" => "issued" })
      expect { described_class.new.run }.not_to(change { [AchTransfer.count, Wire.count, IncreaseCheck.count] })

      expect(payout_holding.reload).to be_sent
      expect(payout_holding.payout_transfer.column_id).to eq("column_transfer")
      expect(payout_holding.paypal_transfer).to be_nil
      expect(payout_holding.wise_transfer).to be_nil
      expect(paypal_transfer.reload).to be_failed
      expect(wise_transfer.reload).to be_failed
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
    let(:remote_status) { "SUBMITTED" }

    include_examples "a reimbursement payout", ["returned", "canceled"]
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
    let(:remote_status) { "submitted" }

    include_examples "a reimbursement payout", ["returned", "canceled"]
  end

  context "with a check" do
    let(:details) do
      LegalEntity::PayoutMethod::Check.new(
        address_line1: "123 Main St", address_city: "Burlington", address_state: "VT", address_postal_code: "05401"
      )
    end
    let(:endpoint) { "/transfers/checks/issue" }
    let(:failure_mail) { :check_failed }
    let(:remote_status) { "issued" }

    include_examples "a reimbursement payout", ["rejected", "stopped"]
  end
end
