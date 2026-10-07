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
            check = payout_method.create_transfer(
              payment.employee.event,
              memo: "Payment for \"#{payment.title}\".",
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
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
            ach_transfer = payout_method.create_transfer(
              payment.employee.event,
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
              user: User.system_user,
              company_entry_description: "SALARY"
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
