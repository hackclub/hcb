# frozen_string_literal: true

module Payroll
  class PositionMailer < ApplicationMailer
    def onboarding
      @position = params[:position]
      @party = params[:party]
      @payee = @position.payee
      @event = @position.event

      mail to: recipients,
           subject: "[Action Required] Complete your onboarding to get paid as a contractor for #{@event.name}",
           reply_to: reply_to_addresses
    end

    def onboarding_reminder
      @position = params[:position]
      @reminder_number = params[:reminder_number]
      @payee = @position.payee
      @event = @position.event
      @next_step = @position.next_onboarding_step

      mail to: recipients,
           subject: "[Action Required] Finish your onboarding to get paid by #{@event.name}",
           reply_to: reply_to_addresses
    end

    private

    def recipients
      legal_entity = @payee.legal_entity

      if legal_entity&.users&.any?
        legal_entity.users.map(&:email_address_with_name)
      else
        [@payee.email]
      end
    end

    def reply_to_addresses
      manager_emails = @event.organizer_positions.where(role: :manager).includes(:user).map { |op| op.user.email_address_with_name }
      creator_email = @position.contracts.not_voided.first&.party(:organizer)&.user&.email_address_with_name

      [*manager_emails, creator_email].compact.uniq
    end

  end
end
