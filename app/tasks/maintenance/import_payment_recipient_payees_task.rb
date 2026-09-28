# frozen_string_literal: true

module Maintenance
  # Imports the old transfer system's recipients as payees: one managed legal
  # entity per email per event, with each distinct set of saved details as a payout method.
  class ImportPaymentRecipientPayeesTask < MaintenanceTasks::Task
    # payment_model => [association on the recipient, states in which the money left, fields saying where it went]
    SENT_TRANSFERS = {
      AchTransfer.name   => [:ach_transfers, %w[in_transit deposited], %i[account_number routing_number]],
      IncreaseCheck.name => [:increase_checks, %w[approved], %i[address_line1 address_line2 address_city address_state address_zip]],
      Wire.name          => [:wires, %w[approved deposited], %i[account_number bic_code]],
    }.freeze

    # Payouts HCB sends itself; no organizer ever typed in their recipients.
    SYSTEM_PAYOUTS = %i[reimbursement_payout_holding employee_payment].freeze

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
      transfers(recipient)&.any? do |transfer|
        # A contractor's payment attempt still marks their transfer once it's soft deleted.
        Payment::Attempt.with_deleted.exists?(payout: transfer) || SYSTEM_PAYOUTS.any? { |payout| transfer.try(payout) }
      end
    end

    def import(event, email, recipients)
      recipients = ranked(recipients)

      ActiveRecord::Base.transaction do
        legal_entity = LegalEntity.create!(managing_event: event)

        default = nil
        payout_details_for(recipients).each do |recipient, (details_class, attributes)|
          next unless create_payout_method(legal_entity, details_class, attributes, recipient, default: default.nil?)

          default ||= recipient
        end

        # Named after whoever the default pays; the name is sent to TaxBandits, so it can't be empty.
        name = default&.name.presence || recipients.find { |recipient| recipient.name.present? }&.name || email
        legal_entity.update!(name:)
        # Dated like the recipients, since the picker lists the newest payees first.
        event.payees.create!(display_name: name, email:, legal_entity:, imported_at: Time.current, created_at: recipients.map(&:created_at).max)
      end
    end

    # Ranked by when money last went out on each, then by recency.
    def ranked(recipients)
      recipients.sort_by { |recipient| [last_sent_at(recipient) || Time.zone.at(0), recipient.created_at] }.reverse
    end

    # One per distinct set of details, keeping the best ranked.
    def payout_details_for(recipients)
      recipients.map { |recipient| [recipient, detail_attributes(recipient)] }
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
          address_line2: recipient.address_line2.presence,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_zip
        }]
      when Wire.name
        [LegalEntity::PayoutMethod::Wire, {
          account_number: recipient.account_number,
          bic_code: recipient.bic_code,
          address_line1: recipient.address_line1,
          address_line2: recipient.address_line2.presence,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_postal_code,
          recipient_country: recipient.recipient_country,
          recipient_name: recipient.name,
          # Each transfer sets these itself, which is why the payout form leaves them out too.
          recipient_information: recipient.recipient_information.to_h.except("remittance_info", "purpose_code")
        }]
      end
    end

    def transfers(recipient)
      association, _states = SENT_TRANSFERS[recipient.payment_model]
      recipient.public_send(association) if association
    end

    def last_sent_at(recipient)
      _association, states, destination = SENT_TRANSFERS[recipient.payment_model]
      return if destination.nil?

      sent = transfers(recipient).where(aasm_state: states)
      # A stopped or returned check stays approved.
      sent = sent.where.not(id: IncreaseCheck.canceled) if recipient.payment_model == IncreaseCheck.name
      # Reusing a saved recipient overwrites its details, so only sends to the ones it holds now count.
      sent.select { |transfer| destination.all? { |field| transfer.public_send(field) == recipient.public_send(field) } }
          .map(&:created_at).max
    end

  end
end
