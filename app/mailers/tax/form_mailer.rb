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

      if @form.legal_entity.managed?
        @recipients = @form.legal_entity.emails
      else
        @recipients = @form.legal_entity.users.map(&:email_address_with_name)
      end
    end

  end
end
