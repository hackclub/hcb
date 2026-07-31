# frozen_string_literal: true

module Maintenance
  # One-time import of the legacy PaymentRecipient records into Payee, so
  # organizers keep seeing everyone they've paid before in the new payments UI
  # without the new system having to query the old transfer models.
  #
  # Only the name and email come across. The payout details stored on the legacy
  # recipient are deliberately left behind: linking them to a payee would mean
  # trusting that whoever typed in that email address also owns those bank
  # accounts. The recipient re-enters their own payout method when they onboard.
  class ImportPaymentRecipientsToPayeesTask < MaintenanceTasks::Task
    def collection
      # PaymentRecipient's default scope eager-loads and orders by ach_transfers,
      # which fights with the cursor this task pages through the table with.
      PaymentRecipient.unscoped
                      .where.not(email: [nil, ""])
                      .where.not(name: [nil, ""])
    end

    def process(recipient)
      return if existing_payee?(recipient)

      Payee.create!(
        event_id: recipient.event_id,
        display_name: recipient.name,
        email: recipient.email,
        imported_at: Time.current
      )
    end

    private

    def existing_payee?(recipient)
      Payee.where(event_id: recipient.event_id)
           .where("LOWER(payees.email) = ?", recipient.email.strip.downcase)
           .exists?
    end

  end
end
