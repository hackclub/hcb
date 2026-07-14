# frozen_string_literal: true

module Payroll
  class PositionMailer < ApplicationMailer
    def onboarding
      @position = params[:position]
      @payee = @position.payee
      @event = @position.event
      legal_entity = @payee.legal_entity

      recipients = if legal_entity&.users&.any?
                     legal_entity.users.map(&:email_address_with_name)
                   else
                     [@payee.email]
                   end

      mail to: recipients,
           subject: "[Action Required] Complete your onboarding to get paid as a contractor for #{@event.name}"
    end

  end
end
