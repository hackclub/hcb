# frozen_string_literal: true

module LostReceipt
  class Statement
    include ActiveModel::Model
    include ActiveModel::Attributes

    CONFIRMATION = "I confirm these details are accurate and that I have made every effort possible to get the receipt."

    attr_accessor :receipt, :receiptable, :submitter, :merchant, :purpose, :signer_name, :confirmed_at

    attribute :date, :date
    attribute :confirmed, :boolean
    attribute :items, default: -> { [] }

    validates :date, :merchant, :purpose, :signer_name, presence: true
    validates :merchant, :signer_name, length: { maximum: 255 }
    validates :confirmed, acceptance: { accept: true, allow_nil: false }
    validates :items, length: { minimum: 1, maximum: 50 }
    validate :date_is_not_in_the_future
    validate :items_are_valid
    validate :total_matches_transaction

    def items_attributes=(attributes)
      attributes = attributes.values if attributes.is_a?(Hash)
      # Checked before building items so a huge request can't allocate them all.
      raise ActiveRecord::NestedAttributes::TooManyRecords if attributes.size > 50

      self.items = attributes.reject { |item| item.values.all?(&:blank?) }.map { |item| Item.new(item) }
    end

    # The receipt is only saved once the PDF is stored, so a failed render or
    # upload leaves the transaction missing its receipt.
    def submit(receiptable: self.receiptable)
      self.receiptable = receiptable
      return false unless valid?

      self.confirmed_at = Time.current
      self.receipt = Receipt.new(receiptable:, user: submitter, upload_method: :lost_receipt_statement, lost_receipt_statement: self)
      html = ApplicationController.render(template: "lost_receipt/statements/statement", formats: [:pdf], layout: false, assigns: { statement: self })
      io = StringIO.new(CloudflareBrowserRun.pdf(html))
      # Created before uploading so a partial upload can still be purged.
      blob = ActiveStorage::Blob.create_after_unfurling!(io:, filename: "lost-receipt-statement.pdf", content_type: "application/pdf")
      blob.upload(io)
      receipt.file.attach(blob)
      receipt.save!
      true
    rescue ActiveRecord::RecordInvalid => error
      errors.add(:base, error.record.errors.full_messages.to_sentence)
      false
    rescue Faraday::Error, ActiveStorage::Error => error
      Rails.error.report(error)
      errors.add(:base, "The PDF couldn't be generated. Please try again.")
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

    def total_matches_transaction
      charged = receiptable.try(:amount_cents)&.abs
      return if charged.nil? || items.empty? || items.any?(&:invalid?) || total_amount_cents == charged

      errors.add(:base, "The items add up to #{Money.new(total_amount_cents, "USD").format}, but the transaction was #{Money.new(charged, "USD").format}")
    end

    def items_are_valid
      items.each_with_index do |item, index|
        next if item.valid?

        item.errors.full_messages.each { |message| errors.add(:base, "Item #{index + 1}: #{message}") }
      end
    end

  end
end
