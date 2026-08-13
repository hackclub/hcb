class BackfillSensitiveOnAhoyMessages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  SENSITIVE_MAILERS = [
    "LoginCodeMailer#send_code",
    "GSuiteAccountMailer#notify_user_of_activation",
    "GSuiteAccountMailer#notify_user_of_reset",
    "User::EmailUpdateMailer#authorization",
    "User::EmailUpdateMailer#verification",
  ].freeze

  # Defined locally so the backfill doesn't load `Ahoy::Message`, whose
  # `encrypts :content` would be pulled in for rows this never reads.
  class AhoyMessage < ActiveRecord::Base
    self.table_name = "ahoy_messages"
  end

  def up
    AhoyMessage
      .where(sensitive: false, mailer: SENSITIVE_MAILERS)
      .in_batches(of: 1_000)
      .update_all(sensitive: true)
  end

  def down
    AhoyMessage
      .where(sensitive: true)
      .in_batches(of: 1_000)
      .update_all(sensitive: false)
  end
end
