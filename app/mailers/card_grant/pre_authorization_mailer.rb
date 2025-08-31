# frozen_string_literal: true

class CardGrant
  class PreAuthorizationMailer < ApplicationMailer
    def notify_fraudulent
      @pre_authorization = params[:pre_authorization]

      mail to: @pre_authorization.event.organizer_contact_emails(only_managers: true), subject: "A card grant pre-authorization requires your review"
    end

  end

end
