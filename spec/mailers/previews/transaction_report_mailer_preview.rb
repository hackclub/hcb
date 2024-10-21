# frozen_string_literal: true

class TransactionReportMailerPreview < ActionMailer::Preview
  def tell_zach
    TransactionReportMailer.tell_zach
  end

end
