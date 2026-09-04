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
# If this spec is failing, the failure message tells you exactly what to do; you
# do not need to read this file to fix it.
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
      "Payroll::PositionMailer#terminated",
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
    expect(unreviewed).to be_empty, unreviewed_instructions(unreviewed)

    stale = reviewed_mailer_actions - actual
    expect(stale).to be_empty, stale_instructions(stale)
  end

  it "keeps REVIEWED_MAILER_ACTIONS sorted and free of duplicates" do
    duplicates = reviewed_mailer_actions.tally.select { |_, count| count > 1 }.keys
    expect(duplicates).to be_empty, duplicate_instructions(duplicates)

    misplaced = reviewed_mailer_actions.each_cons(2).reject { |earlier, later| earlier < later }
    expect(misplaced).to be_empty, unsorted_instructions(misplaced)
  end

  private

  def duplicate_instructions(actions)
    <<~MESSAGE
      REVIEWED_MAILER_ACTIONS lists the same action more than once:

      #{bulleted(actions)}

      WHAT TO DO
        Delete the duplicate lines. A duplicate usually means two people added
        the same new mailer action to different parts of the list, which is the
        thing keeping it sorted is meant to prevent.
    MESSAGE
  end

  def unsorted_instructions(pairs)
    <<~MESSAGE
      REVIEWED_MAILER_ACTIONS is not alphabetically sorted. Out of order:

      #{bulleted(pairs.map { |earlier, later| "#{earlier.inspect} appears before #{later.inspect}" })}

      WHY THIS MATTERS
        The comparison above does not care about order, so nothing is broken
        right now. Sorting is enforced because an unsorted list makes it easy to
        append a duplicate, and makes every diff to this file harder to read.

      WHAT TO DO
        Move the entries into alphabetical order. Note this is Ruby string sort,
        so "User::EmailUpdateMailer#..." sorts before "UserMailer#...", because
        ":" precedes "M".

        You can regenerate the entire list, but ONLY when the other example in
        this file passes. If a new mailer action exists and you regenerate, you
        will silently mark it reviewed without anyone having looked at it, which
        defeats the point of the tripwire.
    MESSAGE
  end

  def bulleted(actions)
    actions.map { |action| "  #{action}" }.join("\n")
  end

  def unreviewed_instructions(actions)
    <<~MESSAGE
      #{actions.size} mailer action(s) exist that are not in REVIEWED_MAILER_ACTIONS:

      #{bulleted(actions)}

      WHY THIS FAILED
        `has_sensitive_contents` is opt in. Until a mailer declares it, its emails
        are readable in /admin/emails by every auditor, which is the entire
        read-only admin population. This list is the tripwire that makes someone
        look at each new mailer action once.

      WHAT TO DO
        1. Open each action's template under app/views/ and read what it renders.

        2. Decide whether the email contains a secret. It does if it renders a
           login code, a password, an API key, a token, a `signed_id`, or a link
           that grants access to whoever holds it. Grep the template for `_url(`
           with a token or `s:` argument. It does NOT count as a secret merely
           because the email concerns money or is personal.

        3a. If it DOES contain a secret, declare it on the mailer class:

              class WhateverMailer < ApplicationMailer
                has_sensitive_contents
              end

            app/mailers/login_code_mailer.rb is a live example. Declare it bare,
            covering the whole mailer, wherever you can. If some actions on that
            mailer genuinely carry no secret, use `except: [:safe_action]` rather
            than `only: [:risky_action]`. With `only:`, the NEXT action added to
            the mailer is visible to auditors by default; with `except:` it is
            restricted by default. Fail closed.

            Also add a case to spec/mailers/sensitive_contents_spec.rb proving the
            flag gets set, since this spec checks that a decision was recorded,
            not that the declaration works.

        3b. If it does NOT contain a secret, change nothing else. The email stays
            visible to admins, which is what makes /admin/emails useful.

        4. Either way, add the action(s) to REVIEWED_MAILER_ACTIONS in this file
           so this spec passes. Keep the list alphabetically sorted.
    MESSAGE
  end

  def stale_instructions(actions)
    <<~MESSAGE
      #{actions.size} entry/entries in REVIEWED_MAILER_ACTIONS no longer exist:

      #{bulleted(actions)}

      WHAT TO DO
        Remove them from REVIEWED_MAILER_ACTIONS in this file. They were deleted
        or renamed.

        If an action was RENAMED and it sends a secret, also update
        app/tasks/maintenance/backfill_sensitive_ahoy_messages_task.rb. That task
        matches the `mailer` string stored on each `ahoy_messages` row, and
        historical rows keep the OLD name forever, so a renamed sensitive action
        needs BOTH names listed there or its history stays readable by auditors.
    MESSAGE
  end
end
