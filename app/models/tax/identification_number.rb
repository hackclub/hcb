# frozen_string_literal: true

module Tax
  class IdentificationNumber
    def initialize(tin_hash:, legal_entity: nil)
      @tin_hash = tin_hash
      @legal_entity = legal_entity
    end

    def legal_entities
      # A nil tin_hash does not identify a taxpayer, so it must never be used as
      # a grouping key (WHERE tin_hash IS NULL would collapse every TIN-less
      # entity into one). Fall back to just the originating entity, if known.
      @legal_entities ||= if @tin_hash.present?
                            LegalEntity.where(tin_hash: @tin_hash)
                          elsif @legal_entity
                            LegalEntity.where(id: @legal_entity.id)
                          else
                            LegalEntity.none
                          end
    end

    def predicted_to_be_over_threshold?
      payments_sum >= Tax::REPORTING_THRESHOLD_1099
    end

    def banned?
      legal_entities.any? { |le| le.banned_reason.present? }
    end

    def payments
      p = Payment.joins(:payee).where(payee: { legal_entity: legal_entities })
      successful = p.successful_or_sent.where("date_part('year', sent_at) = ?", Tax.year)
      successful.or(p.pending_or_under_review)
    end

    def payments_sum
      payments.sum(:amount_cents)
    end

  end
end
