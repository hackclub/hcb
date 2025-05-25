# frozen_string_literal: true

class User
  class BackupCodeMailerPreview < ActionMailer::Preview
    def new_codes_generated
      User::BackupCodeMailer.with(user_id: User.first.id).new_codes_generated
    end

    def code_used
      User::BackupCodeMailer.with(user_id: User.first.id).code_used
    end

    def backup_codes_enabled
      User::BackupCodeMailer.with(user_id: User.first.id).backup_codes_enabled
    end

    def backup_codes_disabled
      User::BackupCodeMailer.with(user_id: User.first.id).backup_codes_disabled
    end

    def three_or_fewer_codes_remaining
      User::BackupCodeMailer.with(user_id: User.first.id).three_or_fewer_codes_remaining
    end

    def no_codes_remaining
      User::BackupCodeMailer.with(user_id: User.first.id).no_codes_remaining
    end

  end

end
