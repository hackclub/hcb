# frozen_string_literal: true

class Receipt
  class AutoRotateJob < ApplicationJob
    queue_as :low
    discard_on(RTesseract::Error)
    discard_on(MiniMagick::Error)
    discard_on(ActiveJob::DeserializationError) do |_job, exception|
      raise(exception) unless exception.cause.is_a?(ActiveRecord::RecordNotFound)
    end

    def perform(receipt)
      receipt.auto_rotate!
    end

  end

end
