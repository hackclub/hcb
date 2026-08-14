# frozen_string_literal: true

module Admin
  module PaymentApprovable
    extend ActiveSupport::Concern

    class LegalEntityNotPayableError < StandardError; end

    included do
      def ensure_legal_entity_payable!(transfer, classification: nil)
        payment = transfer.payment

        if payment.present?
          payment.update!(classification:) if classification.present?

          error = nil

          if payment.legal_entity.tin_banned?
            error = "This legal entity's TIN has been banned"
          elsif payment.legal_entity.archived?
            error = "This legal entity has been archived"
          elsif !payment.legal_entity.payable?(requires_tax_form: payment.requires_tax_form)
            payment.mark_pending_legal_entity!
            error = "Tax information was missing for this payment and has been requested"
          end

          if error.present?
            current_attempt&.payout&.mark_rejected!
            raise LegalEntityNotPayableError, error
          end
        end
      end

      rescue_from LegalEntityNotPayableError do |e|
        redirect_back fallback_location: root_path, flash: { error: e.message }
      end
    end
  end
end
