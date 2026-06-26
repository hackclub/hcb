# frozen_string_literal: true

module Reimbursement
  module PayoutHoldingService
    class Nightly
      def run
        clearinghouse = Event.find_by(id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
        Reimbursement::PayoutHolding.settled.find_each(batch_size: 100) do |payout_holding|
          payout_holding.with_lock do
            next unless payout_holding.settled?

            payout_method = payout_holding.report.user.default_payout_method&.details

            case payout_method
            when LegalEntity::PayoutMethod::Wire
              Rails.error.handle do
                wire = payout_method.create_transfer(
                  clearinghouse,
                  memo: "Reimbursement for #{payout_holding.report.name}.",
                  payment_for: "Reimbursement for #{payout_holding.report.name}."[0...140],
                  send_email_notification: false,
                  user: User.system_user,
                  currency: "USD"
                )
                begin
                  wire.save!
                  wire.send_wire!
                rescue
                  wire.mark_rejected!
                  payout_holding.mark_failed!
                  reason = "There was an error creating the wire transfer."
                  reason = wire.errors.full_messages.join(", ") if wire.errors.any?
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason:
                  ).wire_failed.deliver_later
                else
                  payout_holding.wire = wire
                  payout_holding.save!
                  payout_holding.mark_sent!
                end
              end
            when LegalEntity::PayoutMethod::Check
              Rails.error.handle do
                check = payout_method.create_transfer(
                  clearinghouse,
                  memo: "Reimbursement for #{payout_holding.report.name}."[0...40],
                  payment_for: "Reimbursement for #{payout_holding.report.name}.",
                  send_email_notification: false,
                  user: User.system_user
                )
                check.save!
                begin
                  check.send_check!
                  payout_holding.increase_check = check
                  payout_holding.save!
                  payout_holding.mark_sent!
                rescue Faraday::Error => e
                  check.mark_rejected!
                  message = e.response_body&.dig("message") || e.message
                  Rails.error.unexpected "[reimbursements / check issuing] #{message}. report ID: #{payout_holding.report.id}"
                end
              end
            when LegalEntity::PayoutMethod::AchTransfer
              Rails.error.handle do
                ach_transfer = payout_method.create_transfer(
                  clearinghouse,
                  memo: "Reimbursement for #{payout_holding.report.name}."[0...40],
                  payment_for: "Reimbursement for #{payout_holding.report.name}.",
                  bank_name: (ColumnService.get("/institutions/#{payout_method.routing_number}")["full_name"] rescue "Bank Account"),
                  send_email_notification: false,
                  creator: User.system_user,
                  company_entry_description: "REIMBURSE"
                )
                ach_transfer.save!
                begin
                  ach_transfer.approve!(User.system_user)
                rescue
                  ach_transfer.mark_rejected!(User.system_user)
                  payout_holding.mark_failed!
                  ReimbursementMailer.with(
                    reimbursement_payout_holding: payout_holding,
                    reason: "Your routing number / account number was invalid."
                  ).ach_failed.deliver_later
                else
                  payout_holding.ach_transfer = ach_transfer
                  payout_holding.save!
                  payout_holding.mark_sent!
                end
              end
            when LegalEntity::PayoutMethod::WiseTransfer
              if payout_holding.created_at < 20.minutes.ago
                Rails.error.unexpected "🚨 WiseTransfer payout holding (#{payout_holding.id}) created more than 20 minutes ago but still unsent."
              end
            else
              raise ArgumentError, "🚨⚠️ unsupported payout method!"
            end
          end
        end

      end

    end
  end
end
