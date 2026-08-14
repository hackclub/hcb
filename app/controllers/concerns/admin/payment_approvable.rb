# frozen_string_literal: true

module Admin
  module PaymentApprovable
    extend ActiveSupport::Concern

    class TaxFormMissingError < StandardError; end

    included do
      def ensure_tax_form_satisifed!(transfer, classification: nil)
        payment = transfer.payment

        if payment.present?
          payment.update!(classification:) if classification.present?

          if !payment.legal_entity.payable?(requires_tax_form: payment.requires_tax_form)
            payment.request_tax_form!
            raise TaxFormMissingError, "Tax information was missing for this payment and has been requested"
          end
        end
      end

      rescue_from Admin::PaymentApprovable::TaxFormMissingError do |e|
        redirect_back fallback_location: root_path, flash: { error: e.message }
      end
    end
  end
end
