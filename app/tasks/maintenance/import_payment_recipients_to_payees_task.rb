# frozen_string_literal: true

module Maintenance
  class ImportPaymentRecipientsToPayeesTask < MaintenanceTasks::Task
    def collection
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
