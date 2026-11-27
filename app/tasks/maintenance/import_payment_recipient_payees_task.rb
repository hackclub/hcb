# frozen_string_literal: true

module Maintenance
  # Imports the old transfer system's recipients as payees: one managed legal
  # entity per email per event, with one payout method per distinct set of
  # details that money successfully went out on. A payee none of whose details
  # import is left without a legal entity.
  class ImportPaymentRecipientPayeesTask < MaintenanceTasks::Task
    # Every transfer on these events is a payout HCB sends itself, so none of
    # their recipients were ever in an org's address book.
    INTERNAL_EVENT_IDS = [EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING].freeze

    # payment_model => states in which the money left
    SENT_STATES = {
      AchTransfer   => %w[in_transit deposited],
      IncreaseCheck => %w[approved],
      Wire          => %w[approved deposited],
    }.freeze

    # payment_model => its column on Reimbursement::PayoutHolding
    REIMBURSEMENT_PAYOUT_COLUMNS = {
      AchTransfer   => :ach_transfer_id,
      IncreaseCheck => :increase_check_id,
      Wire          => :wire_id,
    }.freeze

    # Saved on the original wire for that one payment; create_transfer sets its own.
    PER_WIRE_INFORMATION = %w[purpose_code remittance_info].freeze

    def collection
      Event.unscope(:order)
           .where(id: PaymentRecipient.unscoped.select(:event_id))
           .where.not(id: INTERNAL_EVENT_IDS)
    end

    def process(event)
      recipients_by_email = recipients_to_import(event)
      return if recipients_by_email.empty?

      sent = sent_transfers(recipients_by_email.values.flatten)
      recipients_by_email.each do |email, recipients|
        transfers = recipients.flat_map { |recipient| sent.fetch(recipient.id, []) }
        import(event, email, recipients, transfers.sort_by(&:created_at).reverse)
      end
    end

    private

    def recipients_to_import(event)
      recipients = PaymentRecipient.unscoped.where(event:).to_a.select { |recipient| recipient.email.present? }

      # An existing payee owns its email, and skipping it keeps re-runs idempotent
      # (and cheap: it's checked before anything else is loaded). Compared
      # loosely, since payees saved before email normalization may not be lowercase.
      existing_emails = event.payees.pluck(Arel.sql("lower(btrim(email))")).to_set
      recipients.reject! { |recipient| existing_emails.include?(normalize(recipient.email)) }

      system = system_generated_ids(recipients)
      recipients.reject { |recipient| system.include?(recipient.id) }
                .group_by { |recipient| normalize(recipient.email) }
    end

    def normalize(email)
      email.strip.downcase
    end

    # Recipients written behind payouts HCB sends itself (contractor payments,
    # reimbursements, payroll), which were never in the org's address book.
    def system_generated_ids(recipients)
      ids_by_model(recipients).flat_map do |model, recipient_ids|
        transfers = model.where(payment_recipient_id: recipient_ids)
        transfers.where(id: Payment::Attempt.with_deleted.where(payout_type: model.name).select(:payout_id))
                 .or(transfers.where(id: Employee::Payment.where(payout_type: model.name).select(:payout_id)))
                 .or(transfers.where(id: Reimbursement::PayoutHolding.select(REIMBURSEMENT_PAYOUT_COLUMNS[model])))
                 .distinct
                 .pluck(:payment_recipient_id)
      end.to_set
    end

    # Transfers money successfully went out on, by recipient id.
    # A recipient's saved details are overwritten by every new transfer, even
    # one that later bounces, so each transfer's own details are what was paid.
    def sent_transfers(recipients)
      ids_by_model(recipients).flat_map do |model, recipient_ids|
        sent = model.where(payment_recipient_id: recipient_ids, aasm_state: SENT_STATES[model])
        # A stopped or returned check stays approved.
        sent = sent.where.not(id: IncreaseCheck.canceled) if model == IncreaseCheck
        sent.to_a
      end.group_by(&:payment_recipient_id)
    end

    def ids_by_model(recipients)
      SENT_STATES.keys.filter_map do |model|
        ids = recipients.select { |recipient| recipient.payment_model == model.name }.map(&:id)
        [model, ids] if ids.any?
      end
    end

    def import(event, email, recipients, transfers)
      # The legal entity's name is sent to TaxBandits, so it can't be empty.
      name = latest_name(recipients) || email

      ActiveRecord::Base.transaction do
        legal_entity = nil

        # Rolled back as a whole if nothing imports, so no empty legal entity
        # (or its PaperTrail history) is left behind.
        ActiveRecord::Base.transaction(requires_new: true) do
          candidate = LegalEntity.create!(managing_event: event, name:)

          imported = 0
          payout_details_for(transfers).each do |transfer, (details_class, attributes)|
            imported += 1 if create_payout_method(candidate, details_class, attributes, transfer, default: imported.zero?)
          end

          raise ActiveRecord::Rollback if imported.zero?

          legal_entity = candidate
        end

        event.payees.create!(display_name: name, email:, legal_entity:, imported_at: Time.current)
      end
    end

    # Every transfer overwrites its recipient's name, so the most recently
    # updated recipient carries the most recent one.
    def latest_name(recipients)
      recipients.sort_by(&:updated_at).reverse.filter_map { |recipient| recipient.name.presence }.first
    end

    # Newest transfer first, one per distinct set of details.
    def payout_details_for(transfers)
      transfers.map { |transfer| [transfer, detail_attributes(transfer)] }
               .uniq { |_transfer, details| details }
    end

    # Details that no longer pass validation are logged and left behind.
    def create_payout_method(legal_entity, details_class, attributes, transfer, default:)
      service = LegalEntity::PayoutMethodService::Update.new(
        legal_entity:,
        details_type: details_class.name,
        details_attrs: attributes,
        make_default: default
      )

      # A savepoint, so a database error here can't abort the rest of the import.
      return true if ActiveRecord::Base.transaction(requires_new: true) { service.run }

      skipped(transfer, service.error_messages.to_sentence)
    rescue => e
      skipped(transfer, e.message)
    end

    def skipped(transfer, reason)
      Rails.logger.warn("[ImportPaymentRecipientPayees] #{transfer.class.name} #{transfer.id} (PaymentRecipient #{transfer.payment_recipient_id}) left behind: #{reason}")

      false
    end

    def detail_attributes(transfer)
      case transfer
      when AchTransfer
        [LegalEntity::PayoutMethod::AchTransfer, {
          account_number: transfer.account_number,
          routing_number: transfer.routing_number
        }]
      when IncreaseCheck
        [LegalEntity::PayoutMethod::Check, {
          address_line1: transfer.address_line1,
          address_line2: transfer.address_line2,
          address_city: transfer.address_city,
          address_state: transfer.address_state,
          address_postal_code: transfer.address_zip
        }]
      when Wire
        [LegalEntity::PayoutMethod::Wire, {
          account_number: transfer.account_number,
          bic_code: transfer.bic_code,
          address_line1: transfer.address_line1,
          address_line2: transfer.address_line2,
          address_city: transfer.address_city,
          address_state: transfer.address_state,
          address_postal_code: transfer.address_postal_code,
          recipient_country: transfer.recipient_country,
          recipient_information: (transfer.recipient_information || {}).except(*PER_WIRE_INFORMATION)
        }]
      end
    end

  end
end
