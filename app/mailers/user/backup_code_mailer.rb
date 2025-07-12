# frozen_string_literal: true

class User
  class BackupCodeMailer < ApplicationMailer
    before_action :set_user

    default to: -> { @user.email_address_with_name }

    def new_codes_activated
      mail subject: "You've generated new backup codes for HCB"
    end

    def code_used
      subject = "You've used a backup code to login to HCB"
      case @user.backup_codes.active.size
      when 0
        subject = "[Action Required] You've used all your backup codes for HCB"
      when 1..3
        subject = "[Action Requested] You've almost used all your backup codes for HCB"
      end
      mail subject: subject
    end

    def backup_codes_disabled
      mail subject: "You've disabled your HCB backup codes"
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

  end

end
