# frozen_string_literal: true

module LostReceipt
  class Statement
    class AttachPdfJob < ApplicationJob
      queue_as :default
      # Any other failure won't fix itself, so undo the mark rather than leave it without a PDF.
      # Declared first because later handlers take precedence.
      discard_on StandardError do |job, error|
        Rails.error.report(error)
        job.arguments.first.abandon!(job.arguments.second)
      end
      # The PDF renderer and file storage are both remote; give them a few tries.
      retry_on Faraday::Error, ActiveStorage::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
        Rails.error.report(error)
        job.arguments.first.abandon!(job.arguments.second)
      end
      discard_on ActiveJob::DeserializationError

      def perform(statement, receiptable)
        statement.attach_pdf!(receiptable)
      end

    end

  end

end
