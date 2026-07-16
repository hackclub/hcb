# frozen_string_literal: true

module Payroll
  class PositionMailer < ApplicationMailer
    def onboarding_reminder
      @position = params[:position]
      @reminder_day = params[:reminder_day]
      @event = @position.event
      @legal_entity = @position.payee.legal_entity
      @tax_incomplete = !@legal_entity&.completed_tax_form?
      @payout_incomplete = @legal_entity&.default_payout_method.blank?

      mail(
        to: @position.payee.email,
        subject: "Reminder: finish your onboarding to get paid by #{@event.name}",
        from: hcb_email_with_name_of(@event)
      )
    end

  end
end
