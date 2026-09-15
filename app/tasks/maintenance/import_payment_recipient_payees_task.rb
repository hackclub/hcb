# frozen_string_literal: true

module Maintenance
  # One-time backfill: brings the old transfer system's address book
  # (PaymentRecipient) into the payee system, so imported recipients sit in the
  # same list as every other payee instead of behind their own legacy picker.
  #
  # Every recipient sharing an email within an event collapses into one imported
  # payee, backed by a managed legal entity whose payout methods are those
  # recipients' saved payout details. Only the name and email carry over.
  class ImportPaymentRecipientPayeesTask < MaintenanceTasks::Task
    # payment_model => [association on the recipient, states in which the money left]
    SENT_TRANSFERS = {
      "AchTransfer"   => [:ach_transfers, %w[in_transit deposited]],
      "IncreaseCheck" => [:increase_checks, %w[approved]],
      "Wire"          => [:wires, %w[approved deposited]],
    }.freeze

    def collection
      Event.where(id: PaymentRecipient.unscoped.select(:event_id))
    end

    def process(event)
      recipients_by_email(event).each do |email, recipients|
        # An email the payee flow already knows is left alone: that recipient
        # either owns their payout details or is about to claim them, and on a
        # re-run this is what keeps the import from duplicating itself.
        next if event.payees.exists?(email:)

        import(event, email, recipients)
      end
    end

    private

    def recipients_by_email(event)
      event.payment_recipients
           .reorder(nil)
           .reject { |recipient| recipient.email.blank? }
           .group_by { |recipient| recipient.email.strip.downcase }
    end

    def import(event, email, recipients)
      # Best payout method first: whichever one money last actually went out on,
      # falling back to the most recently saved. An imported payee with no
      # default can't be paid at all until the manual picker ships.
      ranked = recipients.sort_by { |recipient| [last_sent_at(recipient) || Time.zone.at(0), recipient.created_at] }.reverse
      name = recipients.max_by(&:created_at).name.presence

      ApplicationRecord.transaction do
        legal_entity = LegalEntity.create!(managing_event: event, name:)
        event.payees.create!(display_name: name || email, email:, legal_entity:, imported_at: Time.current)

        defaulted = false
        ranked.each do |recipient|
          created = create_payout_method(legal_entity, recipient, default: !defaulted)
          defaulted = true if created
        end
      end
    end

    def create_payout_method(legal_entity, recipient, default:)
      details = build_details(recipient)
      return nil unless details && importable?(details)

      details.save!
      legal_entity.payout_methods.create!(details:, default:)
    end

    def build_details(recipient)
      case recipient.payment_model
      when AchTransfer.name
        LegalEntity::PayoutMethod::AchTransfer.new(
          account_number: recipient.account_number,
          routing_number: recipient.routing_number
        )
      when IncreaseCheck.name
        LegalEntity::PayoutMethod::Check.new(
          address_line1: recipient.address_line1,
          address_line2: recipient.address_line2,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_zip
        )
      when Wire.name
        LegalEntity::PayoutMethod::Wire.new(
          account_number: recipient.account_number,
          bic_code: recipient.bic_code,
          address_line1: recipient.address_line1,
          address_line2: recipient.address_line2,
          address_city: recipient.address_city,
          address_state: recipient.address_state,
          address_postal_code: recipient.address_postal_code,
          recipient_country: recipient.recipient_country,
          recipient_information: recipient.recipient_information || {}
        )
      end
    end

    # Legacy recipients predate today's payout method validations, and the wire
    # ones raise on a missing field rather than failing. Whatever can't be
    # rebuilt cleanly is left behind rather than imported as an unusable method.
    def importable?(details)
      details.valid?
    rescue
      false
    end

    def last_sent_at(recipient)
      association, states = SENT_TRANSFERS[recipient.payment_model]
      return nil if association.nil?

      recipient.public_send(association).where(aasm_state: states).maximum(:created_at)
    end

  end
end
