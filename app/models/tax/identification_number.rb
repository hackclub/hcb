# frozen_string_literal: true

module Tax
  class IdentificationNumber
    def initialize(tin_hash:)
      @tin_hash = tin_hash
    end

    def legal_entities
      @legal_entities ||= LegalEntity.where(tin_hash: @tin_hash)
    end

    def predicted_to_be_over_threshold?
      payments_sum >= Tax::REPORTING_THRESHOLD_1099
    end

    def banned?
      legal_entities.any? { |le| le.banned_reason.present? }
    end

    def payments
      p = Payment.joins(:payee).where(payee: { legal_entity: legal_entities })
      successful = p.successful_or_sent.where("date_trunc('year', sent_at) = ?", "#{Tax.year}-01-01")
      successful.or(p.pending_or_under_review)
    end

    def payments_sum
      payments.sum(:amount_cents)
    end

  end
end
