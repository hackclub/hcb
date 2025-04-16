# frozen_string_literal: true

class Receipt
  class SuggestPairingsJob < ApplicationJob
    queue_as :low
    def perform(receipt)
      ::ReceiptService::Suggest.new(receipt:).run!
    end

  end

end

module ReceiptJob
  SuggestPairings = Receipt::SuggestPairingsJob
end
