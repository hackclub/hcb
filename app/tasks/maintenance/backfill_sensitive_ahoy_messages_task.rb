# frozen_string_literal: true

module Maintenance
  # Flags historical emails whose contents are secrets (login codes, Google
  # Workspace passwords, email change tokens) so the admin email viewer
  # restricts them to superadmins. Going forward the flag is set at delivery by
  # `ApplicationMailer.has_sensitive_contents`; this covers everything sent
  # before that existed.
  #
  # Run it again after the release is live to pick up anything sent during the
  # deploy window.
  #
  # Processed in batches so each iteration is a single UPDATE rather than a
  # query per row.
  class BackfillSensitiveAhoyMessagesTask < MaintenanceTasks::Task
    # Matching on the stored mailer name is rename blind by construction, so
    # actions that have since been renamed need their historical names too.
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

    def collection
      Ahoy::Message.where(sensitive: false, mailer: SENSITIVE_MAILERS).in_batches(of: 1000)
    end

    def process(batch)
      batch.update_all(sensitive: true)
    end

  end
end
