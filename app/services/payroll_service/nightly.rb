# frozen_string_literal: true

module PayrollService
  class Nightly
    def run
      Employee::Payment.organizer_approved.or(Employee::Payment.admin_approved).find_each(batch_size: 100) do |payment|
        case payment.employee.user.payout_method
        when User::PayoutMethod::Check
          safely do
            check = payment.employee.event.increase_checks.build(
              memo: "Payment for \"#{payment.title}\"."[0...40],
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              address_line1: payment.employee.user.payout_method.address_line1,
              address_line2: payment.employee.user.payout_method.address_line2,
              address_city: payment.employee.user.payout_method.address_city,
              address_state: payment.employee.user.payout_method.address_state,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
              address_zip: payment.employee.user.payout_method.address_postal_code,
              user: User.find_by(email: "bank@hackclub.com")
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

            check.send_check! if payment.admin_approved?
          end
        when User::PayoutMethod::AchTransfer
          safely do
            ach_transfer = payment.employee.event.ach_transfers.build(
              amount: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              recipient_name: payment.employee.user.full_name,
              recipient_email: payment.employee.user.email,
              send_email_notification: false,
              routing_number: payment.employee.user.payout_method.routing_number,
              account_number: payment.employee.user.payout_method.account_number,
              bank_name: (ColumnService.get("/institutions/#{payment.employee.user.payout_method.routing_number}")["full_name"] rescue "Bank Account"),
              creator: User.find_by(email: "bank@hackclub.com"),
              company_name: payment.employee.event.name[0...16],
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

            if payment.admin_approved?
              begin
                ach_transfer.approve!(User.find_by(email: "bank@hackclub.com"))
              rescue
                ach_transfer.mark_rejected!(User.find_by(email: "bank@hackclub.com"))
                payment.mark_failed!
              end
            end
          end
        when User::PayoutMethod::PaypalTransfer
          safely do
            paypal_transfer = payment.employee.event.paypal_transfers.build(
              amount_cents: payment.amount_cents,
              payment_for: "Payment for \"#{payment.title}\".",
              memo: "Payment for \"#{payment.title}\".",
              recipient_email: payment.employee.user.payout_method.recipient_email,
              recipient_name: payment.employee.user.name,
              user: User.find_by(email: "bank@hackclub.com")
            )
            paypal_transfer.save!
            payment.payout = paypal_transfer
            payment.save!
            ::ReceiptService::Create.new(
              uploader: payment.employee.user,
              attachments: [payment.invoice.file.blob],
              upload_method: :employee_payment,
              receiptable: paypal_transfer.local_hcb_code
            ).run!
          end
        else
          raise ArgumentError, "🚨⚠️ unsupported payout method!"
        end

      end
    end

  end
end
