# frozen_string_literal: true

module Tax
  class FormMailer < ApplicationMailer
    before_action :set_form

    def completed
      mail to: @recipients, subject: "Thank you for submitting your tax information"
    end

    private

    def set_form
      @form = params[:form]

      # TODO: refactor to LE
      if @payment.legal_entity.present?
        @recipients = @payment.legal_entity.users.map(&:email_address_with_name)
      else
        @recipients = [@payment.payee.email]
      end
    end

  end
end
