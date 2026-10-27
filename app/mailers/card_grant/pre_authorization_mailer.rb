# frozen_string_literal: true

class CardGrant
  class PreAuthorizationMailer < ApplicationMailer
    def notify_fraudulent
      @pre_authorization = params[:pre_authorization]
      @delivery_reason = "you are a manager of #{@pre_authorization.event.name} on HCB."

      mail to: @pre_authorization.event.organizer_contact_emails(only_managers: true), subject: "[#{@pre_authorization.event.name}] A card grant pre-authorization requires your review"
    end

  end

end
