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

    # unscoped: the default scope orders by last ACH transfer, which both eager
    # loads transfers this task doesn't read and drops check and wire recipients.
    def recipients_by_email(event)
      PaymentRecipient.unscoped
                      .where(event:)
                      .reject { |recipient| recipient.email.blank? }
                      .group_by { |recipient| recipient.email.strip.downcase }
    end

    def import(event, email, recipients)
      # Best payout method first: whichever one money last actually went out on,
      # falling back to the most recently saved. An imported payee with no
      # default can't be paid at all until the manual picker ships.
      ranked = recipients.sort_by { |recipient| [last_sent_at(recipient) || Time.zone.at(0), recipient.created_at] }.reverse
      # Newest name wins, but a recipient saved without one never blanks out a
      # name an older row still carries.
      name = recipients.select { |recipient| recipient.name.present? }.max_by(&:created_at)&.name

      ApplicationRecord.transaction do
        legal_entity = LegalEntity.create!(managing_event: event, name:)
        event.payees.create!(display_name: name || email, email:, legal_entity:, imported_at: Time.current)

        imported = []
        ranked.each do |recipient|
          signature = create_payout_method(legal_entity, recipient, default: imported.empty?, seen: imported)
          imported << signature if signature
        end
      end
    end

    # Recipients were saved once per transfer, so the same account or address
    # recurs across them; importing each one would leave the payee picking
    # between identical methods.
    def create_payout_method(legal_entity, recipient, default:, seen:)
      details = build_details(recipient)
      return nil if details.nil? || !importable?(details)

      signature = signature_for(details)
      return nil if seen.include?(signature)

      details.save!
      legal_entity.payout_methods.create!(details:, default:)
      signature
    end

    def signature_for(details)
      [details.class.name, *details.class.permitted_attributes.map { |attribute| details.public_send(attribute) }]
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
    # rebuilt cleanly is left behind rather than imported as an unusable method,
    # and logged, since a silent drop is indistinguishable from an infrastructure
    # failure on a one-time run.
    def importable?(details)
      return true if details.valid?

      log_skipped(details, details.errors.full_messages.to_sentence)
      false
    rescue StandardError => e
      log_skipped(details, e.message)
      false
    end

    def log_skipped(details, reason)
      Rails.logger.warn("[#{self.class.name}] skipped #{details.class.name}: #{reason}")
    end

    def last_sent_at(recipient)
      association, states = SENT_TRANSFERS[recipient.payment_model]
      return nil if association.nil?

      recipient.public_send(association).where(aasm_state: states).maximum(:created_at)
    end

  end
end
