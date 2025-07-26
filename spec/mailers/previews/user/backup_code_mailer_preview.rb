# frozen_string_literal: true

class User
  class BackupCodeMailerPreview < ActionMailer::Preview
    def new_codes_activated
      User::BackupCodeMailer.with(user_id: User.first.id).new_codes_activated
    end

    def code_used
      User::BackupCodeMailer.with(user_id: User.first.id).code_used
    end

    def backup_codes_disabled
      User::BackupCodeMailer.with(user_id: User.first.id).backup_codes_disabled
    end

  end

end
