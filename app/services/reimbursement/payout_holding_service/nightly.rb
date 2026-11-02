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

            recovering_transfer = payout_holding.unresolved_payout? ? payout_holding.payout_transfer : nil
            if payout_holding.failure_reason == "reconciliation_required" ||
               (recovering_transfer && (recovering_transfer.aasm.current_state.in?([:rejected, :failed]) ||
                 (recovering_transfer.is_a?(IncreaseCheck) && (recovering_transfer.column_rejected? || recovering_transfer.column_stopped?))))
              require_reconciliation!(payout_holding)
              next
            end

            # Column may expire idempotency keys after 30 days. Leave a margin
            # and require reconciliation rather than risk resending a payment.
            if payout_holding.failure_reason.in?(["column_unavailable", "retry_window_expired"]) && payout_holding.payout_transfer&.created_at&.<=(29.days.ago)
              require_reconciliation!(payout_holding, reason: "retry_window_expired")
              next
            end

            payout_holding.mark_settled! if payout_holding.failed?

            payout_method = payout_holding.report.payout_method&.details

            Rails.error.handle do
              case recovering_transfer || payout_method
              when Wire, LegalEntity::PayoutMethod::Wire
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
                  payout_holding.update!(wire:, ach_transfer: nil, increase_check: nil, paypal_transfer: nil, wise_transfer: nil)
                  wire.send_wire!
                rescue Faraday::BadRequestError
                  raise if recovering_transfer

                  wire.mark_rejected!
                  payout_holding.mark_failed!
                  reason = "There was an error creating the wire transfer."
                  reason = wire.errors.full_messages.join(", ") if wire.errors.any?
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason:
                  ).wire_failed.deliver_later
                else
                  complete_payout!(payout_holding, recovering: recovering_transfer.present?)
                end
              when IncreaseCheck, LegalEntity::PayoutMethod::Check
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
                payout_holding.update!(increase_check: check, ach_transfer: nil, wire: nil, paypal_transfer: nil, wise_transfer: nil)
                begin
                  check.send_check!
                  complete_payout!(payout_holding, recovering: recovering_transfer.present?)
                rescue Faraday::BadRequestError => e
                  raise if recovering_transfer

                  check.mark_rejected!
                  payout_holding.mark_failed!
                  message = e.response_body&.dig("message") || e.message
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason: message
                  ).check_failed.deliver_later
                  Rails.error.unexpected "[reimbursements / check issuing] #{message}. report ID: #{payout_holding.report.id}"
                end
              when AchTransfer, LegalEntity::PayoutMethod::AchTransfer
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
                payout_holding.update!(ach_transfer:, increase_check: nil, wire: nil, paypal_transfer: nil, wise_transfer: nil)
                begin
                  ach_transfer.approve!(User.system_user)
                rescue Faraday::BadRequestError
                  raise if recovering_transfer

                  ach_transfer.mark_rejected!(User.system_user)
                  payout_holding.mark_failed!
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason: "Your routing number / account number was invalid."
                  ).ach_failed.deliver_later
                else
                  complete_payout!(payout_holding, recovering: recovering_transfer.present?)
                end
              when LegalEntity::PayoutMethod::WiseTransfer
                if payout_holding.created_at < 20.minutes.ago
                  Rails.error.unexpected "🚨 WiseTransfer payout holding (#{payout_holding.id}) created more than 20 minutes ago but still unsent."
                end
              else
                raise ArgumentError, "🚨⚠️ unsupported payout method!"
              end
            rescue Faraday::BadRequestError
              raise unless recovering_transfer

              require_reconciliation!(payout_holding)
            rescue Faraday::Error
              payout_holding.mark_failed!
              payout_holding.update!(failure_reason: "column_unavailable", retry_at: 24.hours.from_now)
              raise
            end
          end
        end

      end

      private

      def require_reconciliation!(payout_holding, reason: "reconciliation_required")
        payout_holding.mark_failed! if payout_holding.settled?
        payout_holding.update!(failure_reason: reason, retry_at: nil)
        Rails.error.report(RuntimeError.new("Reimbursement payout holding #{payout_holding.id} requires reconciliation before retrying"))
      end

      def complete_payout!(payout_holding, recovering:)
        return payout_holding.mark_sent! unless recovering

        transfer = payout_holding.payout_transfer
        case transfer
        when AchTransfer
          remote = ColumnService.ach_transfer(transfer.column_id)
          status = remote["status"].to_s.downcase
          if status.in?(["returned", "canceled"])
            transfer.mark_failed!(reason: remote["return_details"]&.last&.dig("description"))
            return
          end
          sent_statuses = %w[pre_review initiated hold pending_submission submitted settled completed scheduled manual_review manual_review_approved]
        when Wire
          remote = ColumnService.international_wire(transfer.column_id)
          status = remote["status"].to_s.downcase
          if status.in?(["returned", "canceled"])
            transfer.mark_failed!(remote["return_reason"])
            return
          end
          sent_statuses = %w[pre_review initiated hold manual_review pending_review pending_submission submitted completed]
        when IncreaseCheck
          remote = ColumnService.get("/transfers/checks/#{transfer.column_id}")
          status = remote["status"].to_s.downcase
          if status.in?(["rejected", "stopped"])
            transfer.update!(column_object: remote, column_status: status, column_delivery_status: remote["delivery_status"], check_number: remote["check_number"])
            return
          end
          sent_statuses = %w[initiated issued manual_review pending_deposit settled]
        end

        if sent_statuses.include?(status)
          payout_holding.mark_sent!
        else
          require_reconciliation!(payout_holding)
        end
      end

    end
  end
end
