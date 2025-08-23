# frozen_string_literal: true

class Receipt
  class SuggestPairingsJob < ApplicationJob
    queue_as :low
    discard_on(RTesseract::Error)
    discard_on(ActiveJob::DeserializationError) do |_job, exception|
      raise(exception) unless exception.cause.is_a?(ActiveRecord::RecordNotFound)
    end

    def perform(receipt)
      ::ReceiptService::Suggest.new(receipt:).run!
    end

  end

end
