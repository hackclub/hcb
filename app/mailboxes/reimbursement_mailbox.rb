# frozen_string_literal: true

class ReimbursementMailbox < ApplicationMailbox
  # mail --> Mail object, this actual email
  # inbound_email => ActionMailbox::InboundEmail record --> the active storage record

  include Pundit::Authorization
  include HasAttachments

  before_processing :set_attachments
  before_processing :set_user

  def process
    return bounce_missing_attachments unless @attachments
    return bounce_missing_user unless @user

    # All good, now let's create the receipts

    report = @user.reimbursement_reports.create(inviter: @user)

    @attachments.each do |attachment|
      expense = report.expenses.create!(amount_cents: 0)

      receipts = ::ReceiptService::Create.new(
        receiptable: expense,
        uploader: @user,
        attachments: [attachment],
        upload_method: :email_reimbursement
      ).run!

      expense.update(memo: receipts.first.suggested_memo, value: receipts.first.extracted_total_amount_cents.to_f / 100) if receipts.first.suggested_memo
    end

    Reimbursement::MailboxMailer.with(
      mail: inbound_email,
      reply_to: mail.to.first,
      report:,
      receipts_count: report.expenses.size
    ).bounce_success.deliver_now
  end

  private

  def set_user
    @user = User.find_by(email: mail.from[0])
  end

  def bounce_missing_user
    bounce_with Reimbursement::MailboxMailer.with(mail: inbound_email).bounce_missing_user
  end

  def bounce_error
    bounce_with Reimbursement::MailboxMailer.with(
      mail: inbound_email,
      reply_to: mail.to.first
    ).bounce_error
  end

end
