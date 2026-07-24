# frozen_string_literal: true

module EventService
  # Aggregates recipients an event has paid through the legacy transfer systems
  # (ACH transfers, checks, wires) and the old PaymentRecipient records, so they
  # can be surfaced alongside modern payees in the payments UI.
  class PreviousRecipients
    LIMIT_PER_SOURCE = 25
    RESULT_LIMIT = 5

    def initialize(event, query: nil)
      @event = event
      @query = query.presence
    end

    # Whether the event has ever paid anyone through a legacy transfer method.
    # Unfiltered by the query on purpose: it gates whether the picker's search
    # UI is worth showing at all.
    def exists?
      PaymentRecipient.unscoped.where(event: @event).exists? ||
        legacy_scopes.any?(&:exists?)
    end

    # Up to RESULT_LIMIT deduped recipients, most recently used first, excluding
    # anyone who already exists as a modern payee.
    def list
      candidates
        .reject { |_, name, email| name.blank? || email.blank? }
        .sort_by { |created_at, _, _| created_at }
        .reverse
        .uniq { |_, _, email| email.downcase }
        .reject { |_, _, email| existing_payee_emails.include?(email.downcase) }
        .first(RESULT_LIMIT)
        .map { |_, name, email| { name:, email: } }
    end

    private

    def like
      return @like if defined?(@like)

      @like = @query ? "%#{PaymentRecipient.sanitize_sql_like(@query)}%" : nil
    end

    def legacy_scopes
      [@event.ach_transfers, @event.increase_checks, @event.wires]
    end

    def candidates
      @candidates ||= begin
        legacy = PaymentRecipient.unscoped.where(event: @event)
        legacy = legacy.where("name ILIKE :q OR email ILIKE :q", q: like) if like
        rows = legacy.order(created_at: :desc).limit(LIMIT_PER_SOURCE).pluck(:created_at, :name, :email)

        legacy_scopes.each do |scope|
          scope = scope.where("recipient_name ILIKE :q OR recipient_email ILIKE :q", q: like) if like
          rows += scope.order(created_at: :desc).limit(LIMIT_PER_SOURCE).pluck(:created_at, :recipient_name, :recipient_email)
        end

        rows
      end
    end

    def existing_payee_emails
      @existing_payee_emails ||= begin
        emails = candidates.map { |_, _, email| email&.downcase }.compact.uniq
        if emails.any?
          @event.payees.where("LOWER(email) IN (?)", emails).pluck(Arel.sql("LOWER(email)"))
        else
          []
        end
      end
    end

  end
end
