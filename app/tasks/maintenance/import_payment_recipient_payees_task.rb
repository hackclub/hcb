# frozen_string_literal: true

module Maintenance
  # Imports the old transfer system's recipients as payees: one managed legal
  # entity per email per event, with each distinct set of saved details as a payout method.
  class ImportPaymentRecipientPayeesTask < MaintenanceTasks::Task
    # payment_model => [association on the recipient, states in which the money left]
    SENT_TRANSFERS = {
      AchTransfer.name   => [:ach_transfers, %w[in_transit deposited]],
      IncreaseCheck.name => [:increase_checks, %w[approved]],
      Wire.name          => [:wires, %w[approved deposited]],
    }.freeze

    # Payouts HCB sends itself; their recipients were never in an org's address book.
    SYSTEM_PAYOUTS = %i[payment_attempt reimbursement_payout_holding employee_payment].freeze

    def collection
      Event.unscope(:order).where(id: PaymentRecipient.unscoped.select(:event_id))
    end

    def process(event)
      recipients_by_email(event).each do |email, recipients|
        # An existing payee owns this email, and skipping it keeps re-runs idempotent.
        next if event.payees.exists?(email:)

        import(event, email, recipients)
      end
    end

    private

    def recipients_by_email(event)
      event.payment_recipients
           .reject { |recipient| recipient.email.blank? || system_generated?(recipient) }
           .group_by { |recipient| recipient.email.strip.downcase }
    end

    def system_generated?(recipient)
      transfers(recipient)&.any? { |transfer| SYSTEM_PAYOUTS.any? { |payout| transfer.try(payout) } }
    end

    def import(event, email, recipients)
      # The legal entity's name is sent to TaxBandits, so it can't be empty.
      name = latest_name(recipients) || email

      ActiveRecord::Base.transaction do
        legal_entity = LegalEntity.create!(managing_event: event, name:)
        event.payees.create!(display_name: name, email:, legal_entity:, imported_at: Time.current)

        default = true
        payout_details_for(recipients).each do |recipient, (details_class, attributes)|
          next unless create_payout_method(legal_entity, details_class, attributes, recipient, default:)

          default = false
        end
      end
    end

    def latest_name(recipients)
      recipients.sort_by(&:created_at).reverse.filter_map { |recipient| recipient.name.presence }.first
    end

    # Ranked by when money last went out on each, then by recency, one per distinct set of details.
    def payout_details_for(recipients)
      ranked = recipients.sort_by { |recipient| [last_sent_at(recipient) || Time.zone.at(0), recipient.created_at] }
                         .reverse

      ranked.map { |recipient| [recipient, detail_attributes(recipient)] }
            .reject { |_recipient, details| details.nil? }
            .uniq { |_recipient, details| details }
    end

    # Details that no longer pass validation are logged and left behind.
    def create_payout_method(legal_entity, details_class, attributes, recipient, default:)
      service = LegalEntity::PayoutMethodService::Update.new(
        legal_entity:,
        details_type: details_class.name,
        details_attrs: attributes,
        make_default: default
      )

      # A savepoint, so a database error here can't abort the payee's transaction.
      return true if ActiveRecord::Base.transaction(requires_new: true) { service.run }

      skipped(recipient, service.error_messages.to_sentence)
    rescue => e
      skipped(recipient, e.message)
    end

    def skipped(recipient, reason)
      Rails.logger.warn("[ImportPaymentRecipientPayees] PaymentRecipient #{recipient.id} (#{recipient.payment_model}) left behind: #{reason}")

      false
    end

    def detail_attributes(recipient)
      case recipient.payment_model
      when AchTransfer.name
        [LegalEntity::PayoutMethod::AchTransfer, {
          account_number: recipient.account_number,
          routing_number: recipient.routing_number
        }]
      when IncreaseCheck.name
        [LegalEntity::PayoutMethod::Check, {
          address_line1: recipient.address_line1,
          address_line2: recipient.address_line2,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_zip
        }]
      when Wire.name
        [LegalEntity::PayoutMethod::Wire, {
          account_number: recipient.account_number,
          bic_code: recipient.bic_code,
          address_line1: recipient.address_line1,
          address_line2: recipient.address_line2,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_postal_code,
          recipient_country: recipient.recipient_country,
          recipient_information: recipient.recipient_information || {}
        }]
      end
    end

    def transfers(recipient)
      association, _states = SENT_TRANSFERS[recipient.payment_model]
      recipient.public_send(association) if association
    end

    def last_sent_at(recipient)
      _association, states = SENT_TRANSFERS[recipient.payment_model]
      sent = transfers(recipient)&.where(aasm_state: states)
      # A stopped or returned check stays approved.
      sent = sent.where.not(id: IncreaseCheck.canceled) if recipient.payment_model == IncreaseCheck.name
      sent&.maximum(:created_at)
    end

  end
end
