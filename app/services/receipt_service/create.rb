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

      @attachments&.map do |attachment|
        receipt = Receipt.create!(attrs(attachment))
        if Receipt::SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS.include?(@upload_method.to_s)
          ::ReceiptService::Suggest.new(receipt:).run!
        end

        receipt
      end
    end

    private

    def attrs(attachment)
      # A receipt being copied: bring its kept original along, so the copy can
      # still show and undo an automatic rotation.
      if attachment.is_a?(Receipt)
        original_file = attachment.original_file.blob
        attachment = attachment.file.blob
      end

      {
        file: attachment,
        original_file:,
        user: @uploader,
        upload_method: @upload_method,
        receiptable: @receiptable # Receiptable may be nil
      }.compact
    end

  end
end
