# frozen_string_literal: true

module Reimbursement
  module PayoutHoldingService
    class Nightly
      def run
        clearinghouse = Event.find_by(id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
        Reimbursement::PayoutHolding.ready_for_payout.find_each(batch_size: 100) do |payout_holding|
          payout_holding.with_lock do
            next unless payout_holding.settled? || (payout_holding.failed? && payout_holding.failure_reason == "column_unavailable")
            next if payout_holding.retry_at&.future?

            # Column may expire idempotency keys after 30 days. Leave a margin
            # and require reconciliation rather than risk resending a payment.
            if payout_holding.failure_reason.in?(["column_unavailable", "retry_window_expired"]) && payout_holding.payout_transfer&.created_at&.<=(29.days.ago)
              payout_holding.mark_failed! if payout_holding.settled?
              payout_holding.update!(failure_reason: "retry_window_expired", retry_at: nil)
              Rails.error.report(RuntimeError.new("Reimbursement payout holding #{payout_holding.id} requires reconciliation before retrying"))
              next
            end

            payout_holding.mark_settled! if payout_holding.failed?

            payout_method = payout_holding.report.payout_method&.details

            Rails.error.handle do
              case payout_method
              when LegalEntity::PayoutMethod::Wire
                wire = payout_holding.wire
                wire = nil if wire && (wire.rejected? || wire.failed?)
                wire ||= payout_method.create_transfer(
                  clearinghouse,
                  amount: payout_holding.amount_cents,
                  memo: "Reimbursement for #{payout_holding.report.name}.",
                  payment_for: "Reimbursement for #{payout_holding.report.name}.",
                  recipient_name: payout_holding.report.user.full_name,
                  recipient_email: payout_holding.report.user.email,
                  send_email_notification: false,
                  user: User.system_user,
                  currency: "USD",
                  purpose: :reimbursement
                )
                begin
                  wire.save!
                  payout_holding.update!(wire:)
                  wire.send_wire!
                rescue Faraday::BadRequestError
                  wire.mark_rejected!
                  payout_holding.mark_failed!
                  reason = "There was an error creating the wire transfer."
                  reason = wire.errors.full_messages.join(", ") if wire.errors.any?
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason:
                  ).wire_failed.deliver_later
                else
                  payout_holding.mark_sent!
                end
              when LegalEntity::PayoutMethod::Check
                check = payout_holding.increase_check
                check = nil if check && (check.rejected? || check.column_rejected? || check.column_stopped?)
                check ||= payout_method.create_transfer(
                  clearinghouse,
                  amount: payout_holding.amount_cents,
                  memo: "Reimbursement for #{payout_holding.report.name}.",
                  payment_for: "Reimbursement for #{payout_holding.report.name}.",
                  recipient_name: payout_holding.report.user.full_name,
                  recipient_email: payout_holding.report.user.email,
                  send_email_notification: false,
                  user: User.system_user
                )
                check.save!
                payout_holding.update!(increase_check: check)
                begin
                  check.send_check!
                  payout_holding.mark_sent!
                rescue => e
                  raise if e.is_a?(Faraday::Error) && !e.is_a?(Faraday::BadRequestError)

                  check.mark_rejected!
                  payout_holding.mark_failed!
                  message = (e.response_body["message"] if e.respond_to?(:response_body) && e.response_body.is_a?(Hash)) || e.message
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason: message
                  ).check_failed.deliver_later
                end
              when LegalEntity::PayoutMethod::AchTransfer
                ach_transfer = payout_holding.ach_transfer
                ach_transfer = nil if ach_transfer && (ach_transfer.rejected? || ach_transfer.failed?)
                ach_transfer ||= payout_method.create_transfer(
                  clearinghouse,
                  amount: payout_holding.amount_cents,
                  payment_for: "Reimbursement for #{payout_holding.report.name}.",
                  recipient_name: payout_holding.report.user.full_name,
                  recipient_email: payout_holding.report.user.email,
                  send_email_notification: false,
                  user: User.system_user,
                  company_entry_description: "REIMBURSE"
                )
                ach_transfer.save!
                payout_holding.update!(ach_transfer:)
                begin
                  ach_transfer.approve!(User.system_user)
                rescue Faraday::BadRequestError
                  ach_transfer.mark_rejected!(User.system_user)
                  payout_holding.mark_failed!
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason: "Your routing number / account number was invalid."
                  ).ach_failed.deliver_later
                else
                  payout_holding.mark_sent!
                end
              when LegalEntity::PayoutMethod::WiseTransfer
                if payout_holding.created_at < 20.minutes.ago
                  Rails.error.unexpected "🚨 WiseTransfer payout holding (#{payout_holding.id}) created more than 20 minutes ago but still unsent."
                end
              else
                raise ArgumentError, "🚨⚠️ unsupported payout method!"
              end
            rescue Faraday::ServerError, Faraday::ConnectionFailed, Faraday::TimeoutError
              payout_holding.mark_failed!
              payout_holding.update!(failure_reason: "column_unavailable", retry_at: 24.hours.from_now)
              raise
            end
          end
        end

      end

    end
  end
end
