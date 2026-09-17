# frozen_string_literal: true

module Maintenance
  # One-time backfill: brings the old transfer system's address book
  # (PaymentRecipient) into the payee system, so anyone an org has sent a
  # transfer to before shows up in the payee picker alongside everyone else.
  #
  # Every recipient sharing an email within an event collapses into one imported
  # payee, backed by a managed legal entity whose payout methods are those
  # recipients' saved payout details. Only the name and email carry over.
  class ImportPaymentRecipientPayeesTask < MaintenanceTasks::Task
    # payment_model => [association on the recipient, states in which the money left]
    SENT_TRANSFERS = {
      AchTransfer.name   => [:ach_transfers, %w[in_transit deposited]],
      IncreaseCheck.name => [:increase_checks, %w[approved]],
      Wire.name          => [:wires, %w[approved deposited]],
    }.freeze

    def collection
      Event.where(id: PaymentRecipient.unscoped.select(:event_id))
    end

    def process(event)
      recipients_by_email(event).each do |email, recipients|
        # An email the payee flow already knows wins outright: that recipient
        # either owns their payout details or is about to claim them, so
        # whatever the old system recorded against the same email is ignored.
        # On a re-run this is also what keeps the import from duplicating
        # itself or overwriting details their owner has since entered.
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
      # The email stands in for a name nobody ever recorded: the legal entity's
      # name is what we send to TaxBandits when the payee is asked for a tax
      # form, so it can't be left empty.
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

    # The most recent name anyone actually filled in. The newest recipient is
    # not necessarily it: the payout system writes a recipient behind every
    # transfer, and a reimbursement or payroll run can leave the name blank.
    def latest_name(recipients)
      recipients.sort_by(&:created_at).reverse.filter_map { |recipient| recipient.name.presence }.first
    end

    # Best payout method first: whichever one money last actually went out on,
    # falling back to the most recently saved.
    #
    # The old form saves a brand new recipient every time someone types details
    # into it, so the same account turns up over and over; one payout method per
    # distinct set of details, or the payee's picker fills with entries nothing
    # on screen can tell apart.
    def payout_details_for(recipients)
      ranked = recipients.sort_by { |recipient| [last_sent_at(recipient) || Time.zone.at(0), recipient.created_at] }
                         .reverse

      ranked.map { |recipient| [recipient, detail_attributes(recipient)] }
            .reject { |_recipient, details| details.nil? }
            .uniq { |_recipient, details| details }
    end

    # Built through the service the payout form uses, so an imported method is
    # the same thing a payee entering their own details would have produced.
    #
    # Legacy recipients predate today's payout method validations, and the wire
    # ones raise on a missing field rather than failing. Whatever can't be
    # rebuilt cleanly is left behind rather than imported as an unusable method
    # — and logged, because nothing about the payee afterwards says a method
    # went missing.
    def create_payout_method(legal_entity, details_class, attributes, recipient, default:)
      service = LegalEntity::PayoutMethodService::Update.new(
        legal_entity:,
        details_type: details_class.name,
        details_attrs: attributes,
        make_default: default
      )

      return true if service.run

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

    def last_sent_at(recipient)
      association, states = SENT_TRANSFERS[recipient.payment_model]
      return nil if association.nil?

      recipient.public_send(association).where(aasm_state: states).maximum(:created_at)
    end

  end
end
