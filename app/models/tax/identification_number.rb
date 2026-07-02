# frozen_string_literal: true

module Tax
  class IdentificationNumber
    def initialize(tin_hash:)
      @tin_hash = tin_hash
    end

    def legal_entities
      @legal_entities ||= LegalEntity.where(tin_hash: @tin_hash)
    end

    def predicted_to_be_over_theshold?
      payment_sum >= Tax::REPORTING_THRESHOLD_1099
    end

    def banned?
      legal_entities.any?(&:banned?)
    end

    def payments
      p = Payments.where(legal_entity: legal_entities)
      successful = p.successful_or_sent.where("date_trunc('year', sent_at) = ?", Tax.year)
      successful.or(p.pending)
    end

    def payments_sum
      payments.sum(:amount_cents)
    end

  end
end
