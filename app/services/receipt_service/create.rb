# frozen_string_literal: true

module ReceiptService
  class Create
    def initialize(attachments:, uploader:, upload_method: nil, receiptable: nil)
      @attachments = attachments
      @receiptable = receiptable
      @uploader = uploader
      @upload_method = upload_method
    end

    def run!
      if @receiptable&.has_attribute?(:marked_no_or_lost_receipt_at)
        @receiptable&.update(marked_no_or_lost_receipt_at: nil)
      end

      @attachments.map do |attachment|
        receipt = Receipt.create!(attrs(attachment))
        if Receipt::SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS.include?(@upload_method.to_s)
          ::ReceiptService::Suggest.new(receipt:).run!
        end

        receipt
      end
    end

    private

    def attrs(attachment)
      {
        file: attachment,
        user: @uploader,
        upload_method: @upload_method,
        receiptable: @receiptable # Receiptable may be nil
      }
    end

  end
end
