# frozen_string_literal: true

require "rails_helper"

# Emails whose contents are secrets must declare `has_sensitive_contents` so the
# admin email viewer restricts them to superadmins. That declaration is opt in,
# which means a mailer action added later is readable by every auditor unless
# someone notices.
#
# The list below is a baseline of the mailer actions that existed when
# `has_sensitive_contents` was introduced. It is a tripwire, not a certification
# that each entry was individually audited: its job is to force a decision on
# anything new.
#
# When this spec fails, read the new action's template and decide. If it renders
# a login code, a password, a token, or anything else that grants access,
# declare `has_sensitive_contents` on its mailer. Either way, add it to the list.
RSpec.describe "mailer sensitive contents coverage", type: :mailer do
  let(:reviewed_mailer_actions) do
    [
      "AccountNumberMailer#debits_disabled",
      "AccountNumberMailer#insufficent_balance",
      "AccountNumberMailer#set_event_memo_and_amount_cents",
      "AchTransferMailer#notify_failed",
      "AchTransferMailer#notify_recipient",
      "AdminMailer#balance_anomalies",
      "AdminMailer#blocked_authorization",
      "AdminMailer#cash_withdrawal_notification",
      "AdminMailer#fee_anomalies",
      "AdminMailer#linked_object_anomalies",
      "AdminMailer#logical_transaction_anomalies",
      "AdminMailer#reminders",
      "AnnouncementMailer#announcement_published",
      "AnnouncementMailer#notice",
      "AnnouncementMailer#set_warning_variables",
      "AnnouncementMailer#seven_day_warning",
      "AnnouncementMailer#skipped",
      "AnnouncementMailer#two_day_warning",
      "CanonicalPendingTransactionMailer#notify_approved",
      "CanonicalPendingTransactionMailer#notify_declined",
      "CanonicalPendingTransactionMailer#notify_settled",
      "CardGrant::PreAuthorizationMailer#notify_fraudulent",
      "CardGrantMailer#card_grant_expiry_notification",
      "CardGrantMailer#card_grant_notification",
      "CardLockingMailer#cards_locked",
      "CardLockingMailer#cards_unlocked",
      "CardLockingMailer#warning",
      "CheckDepositMailer#deposited",
      "CheckDepositMailer#rejected",
      "CheckDepositMailer#returned",
      "CommentMailer#bounce_missing_comment",
      "CommentMailer#notification",
      "Contract::PartyMailer#notify",
      "Contract::PartyMailer#reissued",
      "Contract::PartyMailer#reminder",
      "DonationMailer#donor_receipt",
      "DonationMailer#first_donation_notification",
      "DonationMailer#notification",
      "DonationMailer#refunded",
      "Employee::PaymentMailer#approved",
      "Employee::PaymentMailer#failed",
      "Employee::PaymentMailer#rejected",
      "Employee::PaymentMailer#review_requested",
      "EmployeeMailer#invitation",
      "Event::ApplicationMailer#activated",
      "Event::ApplicationMailer#approved",
      "Event::ApplicationMailer#confirmation",
      "Event::ApplicationMailer#incomplete",
      "Event::ApplicationMailer#rejected",
      "Event::ApplicationMailer#under_review",
      "EventMailer#donation_goal_reached",
      "EventMailer#monthly_announcements_disabled",
      "EventMailer#monthly_announcements_enabled",
      "EventMailer#monthly_donation_summary",
      "EventMailer#monthly_follower_summary",
      "EventMailer#negative_balance",
      "EventMailer#ops_call_requested",
      "EventMailer#subevent_created",
      "EventMailer#transparency_mode_disabled",
      "EventMailer#transparency_mode_enabled",
      "EventMailer#user_call_requested",
      "ExportMailer#export_ready",
      "FunderInquiryMailer#inquiry",
      "GSuite::RevocationMailer#notify_of_revocation",
      "GSuite::RevocationMailer#organization_managers",
      "GSuite::RevocationMailer#revocation_canceled",
      "GSuite::RevocationMailer#revocation_one_week_warning",
      "GSuite::RevocationMailer#revocation_warning",
      "GSuite::RevocationMailer#set_g_suite",
      "GSuite::RevocationMailer#set_g_suite_and_revocation",
      "GSuite::RevocationMailer#set_reason",
      "GSuiteAccountMailer#notify_user_of_activation",
      "GSuiteAccountMailer#notify_user_of_reset",
      "GSuiteAccountMailer#verify",
      "GSuiteMailer#notify_of_configuring",
      "GSuiteMailer#notify_of_error_after_verified",
      "GSuiteMailer#notify_of_verification_error",
      "GSuiteMailer#notify_of_verified",
      "GSuiteMailer#notify_operations_of_entering_created_state",
      "Governance::Admin::Transfer::ApprovalAttemptMailer#report_denial",
      "HcbCodeMailer#bounce_error",
      "HcbCodeMailer#bounce_missing_attachment",
      "HcbCodeMailer#bounce_missing_hcb",
      "HcbCodeMailer#bounce_missing_user",
      "HcbCodeMailer#bounce_success",
      "IncreaseCheckMailer#notify_recipient",
      "IncreaseCheckMailer#notify_stopped",
      "IncreaseCheckMailer#remind_recipient",
      "InvoiceMailer#notify_organizers_paid",
      "InvoiceMailer#notify_organizers_sent",
      "InvoiceMailer#refunded",
      "LoginCodeMailer#send_code",
      "MailboxMailer#forward",
      "OrganizerPosition::Spending::ControlsMailer#low_balance_warning",
      "OrganizerPosition::Spending::ControlsMailer#new_allowance",
      "OrganizerPositionDeletionRequestMailer#notify_operations",
      "OrganizerPositionInvite::RequestsMailer#created",
      "OrganizerPositionInvite::RequestsMailer#denied",
      "OrganizerPositionInvitesMailer#accepted",
      "OrganizerPositionInvitesMailer#notify",
      "OrganizerPositionMailer#role_change",
      "Payment::AttemptMailer#failed_creator",
      "Payment::AttemptMailer#failed_payee",
      "PaymentMailer#acceptance_reminder",
      "PaymentMailer#missing_payout_method",
      "PaymentMailer#missing_tax_information",
      "PaymentMailer#sent",
      "Payroll::InvoiceMailer#submitted",
      "Payroll::PositionMailer#onboarded",
      "Payroll::PositionMailer#onboarding",
      "Payroll::PositionMailer#onboarding_reminder",
      "RaffleMailer#extra_ticket_earned",
      "ReceiptBinMailer#bounce_error",
      "ReceiptBinMailer#bounce_missing_attachment",
      "ReceiptBinMailer#bounce_missing_user",
      "ReceiptBinMailer#bounce_success",
      "ReceiptableMailer#receipt_report",
      "RecurringDonationMailer#amount_changed",
      "RecurringDonationMailer#canceled",
      "RecurringDonationMailer#payment_failed",
      "RecurringDonationMailer#payment_method_changed",
      "Reimbursement::MailboxMailer#bounce_error",
      "Reimbursement::MailboxMailer#bounce_missing_attachment",
      "Reimbursement::MailboxMailer#bounce_missing_user",
      "Reimbursement::MailboxMailer#bounce_success",
      "ReimbursementMailer#ach_failed",
      "ReimbursementMailer#check_failed",
      "ReimbursementMailer#expenses_approved",
      "ReimbursementMailer#invitation",
      "ReimbursementMailer#paypal_transfer_failed",
      "ReimbursementMailer#reimbursement_approved",
      "ReimbursementMailer#rejected",
      "ReimbursementMailer#reminder",
      "ReimbursementMailer#review_requested",
      "ReimbursementMailer#wire_failed",
      "StripeCard::PersonalizationDesignMailer#design_rejected",
      "StripeCardMailer#lost_in_shipping",
      "StripeCardMailer#physical_card_ordered",
      "StripeCardMailer#virtual_card_ordered",
      "User::BackupCodeMailer#backup_codes_disabled",
      "User::BackupCodeMailer#code_used",
      "User::BackupCodeMailer#new_codes_activated",
      "User::EmailUpdateMailer#authorization",
      "User::EmailUpdateMailer#verification",
      "User::SecurityMailer#security_configuration_changed",
      "User::SessionMailer#new_login",
      "User::SubordinateSummaryMailer#weekly",
      "UserMailer#onboarded",
      "WireMailer#notify_failed",
      "WireMailer#notify_recipient",
      "WiseTransferMailer#notify_failed",
    ].freeze
  end

  it "has a decision recorded for every mailer action" do
    Rails.application.eager_load!

    actual = ApplicationMailer.descendants.flat_map { |mailer|
      mailer
        .action_methods
        .select { |action| mailer.instance_method(action).owner == mailer }
        .map { |action| "#{mailer.name}##{action}" }
    }.sort

    unreviewed = actual - reviewed_mailer_actions
    expect(unreviewed).to be_empty,
                          "New mailer action(s) found. Confirm they send no secrets (declare " \
                          "`has_sensitive_contents` on the mailer if they do), then add them to " \
                          "reviewed_mailer_actions:\n  #{unreviewed.join("\n  ")}"

    stale = reviewed_mailer_actions - actual
    expect(stale).to be_empty,
                     "Stale entries in reviewed_mailer_actions; these mailer actions no longer " \
                     "exist:\n  #{stale.join("\n  ")}"
  end
end
