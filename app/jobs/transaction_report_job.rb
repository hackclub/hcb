# frozen_string_literal: true

class TransactionReportJob < ApplicationJob
  queue_as :low

  def perform
    TransactionReportMailer.tell_zach.deliver_later
  end

end
