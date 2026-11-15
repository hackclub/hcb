# frozen_string_literal: true

class ReceiptBinMailerPreview < ActionMailer::Preview
  def bounce_missing_user
    ReceiptBinMailer.with(
      to: "test@example.com"
    ).bounce_missing_user
  end

  def bounce_missing_attachment
    ReceiptBinMailer.with(
      to: "test@example.com"
    ).bounce_missing_attachment
  end

  def bounce_error
    ReceiptBinMailer.with(
      to: "test@example.com"
    ).bounce_error
  end

  def bounce_success
    ReceiptBinMailer.with(
      to: "test@example.com",
      receipts_count: 1,
      pairs: []
    ).bounce_success
  end

end
