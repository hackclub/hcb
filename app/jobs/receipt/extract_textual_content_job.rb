# frozen_string_literal: true

class Receipt
  class ExtractTextualContentJob < ApplicationJob
    queue_as :low
    def perform(receipt)
      unless receipt.textual_content.present?
        receipt.extract_textual_content!
      end
    end

  end

end

module ReceiptJob
  ExtractTextualContent = Receipt::ExtractTextualContentJob
end
