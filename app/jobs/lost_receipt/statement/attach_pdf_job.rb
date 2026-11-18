# frozen_string_literal: true

module LostReceipt
  class Statement
    class AttachPdfJob < ApplicationJob
      queue_as :default
      # The PDF renderer and file storage are both remote; give them a few tries.
      retry_on Faraday::Error, ActiveStorage::Error, wait: :polynomially_longer, attempts: 5
      discard_on ActiveJob::DeserializationError

      def perform(statement)
        statement.attach_pdf!
      end

    end

  end

end
