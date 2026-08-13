class BackfillSensitiveOnAhoyMessages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Matching on the stored mailer name is rename blind by construction, so
  # actions that have since been renamed need their historical names listed too.
  SENSITIVE_MAILERS = [
    "LoginCodeMailer#send_code",
    "GSuiteAccountMailer#notify_user_of_activation",
    "GSuiteAccountMailer#notify_user_of_reset",
    "User::EmailUpdateMailer#authorization",
    "User::EmailUpdateMailer#verification",
    # Renamed to User::EmailUpdateMailer in 2024.
    "UserMailer#email_update_authorization",
    "UserMailer#email_update_verification",
  ].freeze

  # Defined locally so this backfill keeps working against the schema as it was,
  # regardless of what `Ahoy::Message` grows into later.
  class AhoyMessage < ActiveRecord::Base
    self.table_name = "ahoy_messages"
  end

  def up
    AhoyMessage
      .where(sensitive: false, mailer: SENSITIVE_MAILERS)
      .in_batches(of: 1_000)
      .update_all(sensitive: true)
  end

  # Deliberately a no-op. Un-flagging would clear rows written by the running
  # application as well as the ones this backfilled, re-exposing live login
  # codes. A full rollback drops the column anyway.
  def down
  end
end
