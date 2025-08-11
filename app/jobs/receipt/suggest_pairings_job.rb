# frozen_string_literal: true

class Receipt
  class SuggestPairingsJob < ApplicationJob
    queue_as :low

    discard_on ActiveJob::DeserializationError

    def perform(receipt)
      ::ReceiptService::Suggest.new(receipt:).run!
    end

  end

end
