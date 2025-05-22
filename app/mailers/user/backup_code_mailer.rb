# frozen_string_literal: true

class User
  class BackupCodeMailer < ApplicationMailer
    before_action :set_user

    default to: -> { @user.email_address_with_name }

    def new_codes_generated
      mail subject: "You've generated new backup codes for HCB"
    end

    def code_used
      mail subject: "You've used a backup code to login to HCB"
    end

    def backup_codes_enabled
      mail subject: "HCB backup codes are enabled"
    end

    def backup_codes_disabled
      mail subject: "HCB backup codes are disabled"
    end

    def three_or_fewer_codes_left
      mail subject: "[Action Requested] You've almost used all your backup codes for HCB"
    end

    def no_codes_remaining
      mail subject: "[Action Required] You've used all your backup codes for HCB"
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

  end

end
