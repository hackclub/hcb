# frozen_string_literal: true

module LostReceipt
  class Statement
    include ActiveModel::Model
    include ActiveModel::Attributes

    CONFIRMATION = "I confirm that these purchase details are accurate to the best of my knowledge and that I cannot obtain the original receipt."

    attr_accessor :receipt, :submitter, :merchant, :purpose, :signer_name, :confirmed_at

    attribute :date, :date
    attribute :confirmed, :boolean
    attribute :items, default: -> { [] }

    validates :date, :merchant, :purpose, :signer_name, presence: true
    validates :merchant, :signer_name, length: { maximum: 255 }
    validates :confirmed, acceptance: { accept: true, allow_nil: false }
    validates :items, length: { minimum: 1, maximum: 50 }
    validate :date_is_not_in_the_future
    validate :items_are_valid

    def items_attributes=(attributes)
      attributes = attributes.values if attributes.is_a?(Hash)
      # Keep the existing nested-form request limit before constructing items.
      raise ActiveRecord::NestedAttributes::TooManyRecords if attributes.size > 50

      self.items = attributes.reject { |item| item.values.all?(&:blank?) }.map { |item| Item.new(item) }
    end

    # Generate and store the PDF before attaching it so storage failures cannot
    # resolve the missing receipt.
    def submit(receiptable:)
      return false unless valid?

      self.confirmed_at = Time.current
      self.receipt = Receipt.new(receiptable:, user: submitter, upload_method: :lost_receipt_statement, lost_receipt_statement: self)
      html = ApplicationController.render(template: "lost_receipt/statements/statement", formats: [:pdf], layout: false, assigns: { statement: self })
      pdf = WickedPdf.new.pdf_from_string(html, page_size: "Letter", encoding: "UTF-8", disable_javascript: true)
      io = StringIO.new(pdf)
      # Retain the blob before uploading so even a partial upload can be purged.
      blob = ActiveStorage::Blob.create_after_unfurling!(io:, filename: "lost-receipt-statement.pdf", content_type: "application/pdf")
      blob.upload(io)
      receipt.file.attach(blob)
      receipt.save!
      true
    rescue ActiveRecord::RecordInvalid => error
      errors.add(:base, error.record.errors.full_messages.to_sentence)
      false
    rescue RuntimeError, ActiveStorage::Error => error
      Rails.error.report(error)
      errors.add(:base, "The statement could not be created. Please try again.")
      false
    ensure
      blob&.purge if blob && !receipt&.persisted?
    end

    def total_amount_cents
      items.sum(&:total_amount_cents)
    end

    private

    def date_is_not_in_the_future
      errors.add(:date, "can't be in the future") if date && date > Date.current
    end

    def items_are_valid
      items.each_with_index do |item, index|
        next if item.valid?

        item.errors.full_messages.each { |message| errors.add(:base, "Item #{index + 1}: #{message}") }
      end
    end

  end
end
