# frozen_string_literal: true

class ReceiptBinMailbox < ApplicationMailbox
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

    result = ::ReceiptService::Create.new(
      # `receiptable` is intentionally `nil` to send it to the Receipt Bin
      uploader: @user,
      attachments: @attachments,
      upload_method: "email_receipt_bin"
    ).run!

    return bounce_error if result.empty?

    paired_with = result.map { |r| r.reload.receiptable }.select(&:present?)

    ReceiptBinMailer.with(
      mail: inbound_email,
      reply_to: mail.to.first,
      receipts_count: result.size,
      paired_with:
    ).bounce_success.deliver_now
  end

  private

  RECEIPTS_ADDRESSES = ["receipts@hackclub.com", "receipts@hcb.gg"].freeze

  def set_user
    if mail.recipients.any? { |addr| RECEIPTS_ADDRESSES.include?(addr) }
      @user = User.find_by(email: mail.from[0])
    else
      @user =
        MailboxAddress
        .activated
        .where(address: mail.recipients)
        .order(id: :desc)
        .first
        &.user
    end
  end

  def bounce_missing_user
    bounce_with ReceiptBinMailer.with(mail: inbound_email).bounce_missing_user
  end

  def bounce_error
    bounce_with ReceiptBinMailer.with(
      mail: inbound_email,
      reply_to: mail.to.first
    ).bounce_error
  end

end
