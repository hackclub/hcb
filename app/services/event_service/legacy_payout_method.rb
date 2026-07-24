# frozen_string_literal: true

module EventService
  # Rebuilds a payout method from a recipient's most recent legacy transfer so
  # that, when an organizer chooses to submit payout info on a legacy
  # recipient's behalf, HCB can pre-fill the method it already has on file
  # (account & routing number, check address, or wire details) instead of
  # asking for it again.
  class LegacyPayoutMethod
    # Legacy transfer models that carry recipient payout details, mapped to the
    # builder that turns one into an (unsaved) payout method details record.
    SOURCES = {
      AchTransfer   => :ach_details,
      IncreaseCheck => :check_details,
      Wire          => :wire_details,
    }.freeze

    # Matched on email only: a recipient is keyed by their email, and the same
    # person may have been paid under slightly different names across transfers.
    def initialize(event, email:)
      @event = event
      @email = email.to_s.strip.downcase
    end

    # Returns an unsaved LegalEntity::PayoutMethod::* details record built from
    # the recipient's most recent legacy transfer, or nil if none matches.
    def details
      details_list.first
    end

    # Returns one unsaved LegalEntity::PayoutMethod::* details record per method
    # type the recipient was previously paid with (each built from the most
    # recent transfer of that type), ordered most-recently-used first. Empty if
    # none matches.
    def details_list
      return [] if @email.blank?

      SOURCES
        .filter_map { |model, builder| record = latest_for(model); [record, builder] if record }
        .sort_by { |record, _builder| record.created_at }
        .reverse
        .map { |record, builder| send(builder, record) }
    end

    private

    def latest_for(model)
      table = model.arel_table

      model.unscoped
           .where(event: @event)
           .where(lower(table[:recipient_email]).eq(@email))
           .order(created_at: :desc)
           .first
    end

    def ach_details(transfer)
      LegalEntity::PayoutMethod::AchTransfer.new(
        account_number: transfer.account_number,
        routing_number: transfer.routing_number
      )
    end

    def check_details(transfer)
      LegalEntity::PayoutMethod::Check.new(
        address_line1: transfer.address_line1,
        address_line2: transfer.address_line2,
        address_city: transfer.address_city,
        address_state: transfer.address_state,
        address_postal_code: transfer.address_zip,
        address_country: "US"
      )
    end

    def wire_details(transfer)
      LegalEntity::PayoutMethod::Wire.new(
        address_line1: transfer.address_line1,
        address_line2: transfer.address_line2,
        address_city: transfer.address_city,
        address_state: transfer.address_state,
        address_postal_code: transfer.address_postal_code,
        recipient_country: transfer.recipient_country,
        recipient_name: transfer.recipient_name,
        account_number: transfer.account_number,
        bic_code: transfer.bic_code,
        recipient_information: transfer.recipient_information
      )
    end

    def lower(column)
      Arel::Nodes::NamedFunction.new("LOWER", [column])
    end

  end
end
