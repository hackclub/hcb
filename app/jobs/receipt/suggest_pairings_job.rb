# frozen_string_literal: true

class Receipt
  class SuggestPairingsJob < ApplicationJob
    queue_as :low
    def perform(receipt)
      ::ReceiptService::Suggest.new(receipt:).run!
    end

    discard_on ActiveRecord::RecordNotFound, RTesseract::Error

  end

end
