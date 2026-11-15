# frozen_string_literal: true

module PayrollService
  class Nightly
    def run
      Employee::Payment.approved.find_each(batch_size: 100) do |payment|
        next if payment.payout.present?

        payout_method = payment.employee.user.default_payout_method&.details

        case payout_method
        when LegalEntity::PayoutMethod::Check
          safely do
            check = payment.employee.event.increase_checks.build(
              memo: "Payment for \"#{payment.title}\"."[0...40],
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              address_line1: payout_method.address_line1,
              address_line2: payout_method.address_line2,
              address_city: payout_method.address_city,
              address_state: payout_method.address_state,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
              address_zip: payout_method.address_postal_code,
              user: User.system_user
            )

            check.save!

            payment.payout = check
            payment.save!

            ::ReceiptService::Create.new(
              uploader: payment.employee.user,
              attachments: [payment.invoice.file.blob],
              upload_method: :employee_payment,
              receiptable: check.local_hcb_code
            ).run!

            check.send_check! if payment.previously_paid?
          end
        when LegalEntity::PayoutMethod::AchTransfer
          safely do
            ach_transfer = payment.employee.event.ach_transfers.build(
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
              routing_number: payout_method.routing_number,
              account_number: payout_method.account_number,
              bank_name: (ColumnService.get("/institutions/#{payout_method.routing_number}")["full_name"] rescue "Bank Account"),
              creator: User.system_user,
              company_entry_description: "SALARY",
            )

            ach_transfer.save!

            payment.payout = ach_transfer
            payment.save!

            ::ReceiptService::Create.new(
              uploader: payment.employee.user,
              attachments: [payment.invoice.file.blob],
              upload_method: :employee_payment,
              receiptable: ach_transfer.local_hcb_code
            ).run!

            if payment.previously_paid?
              begin
                ach_transfer.approve!(User.system_user)
              rescue
                ach_transfer.mark_rejected!(User.system_user)
                payment.mark_failed!
              end
            end
          end
        else
          raise ArgumentError, "🚨⚠️ unsupported payout method!"
        end

      end
    end

  end
end
