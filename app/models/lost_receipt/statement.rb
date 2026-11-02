# frozen_string_literal: true

module LostReceipt
  class Statement < ApplicationRecord
    CONFIRMATION = "I confirm that these purchase details are accurate to the best of my knowledge and that I cannot obtain the original receipt."

    belongs_to :receipt, inverse_of: :lost_receipt_statement, optional: true
    belongs_to :submitter, class_name: "User", optional: true
    has_many :items, dependent: :destroy, inverse_of: :statement
    accepts_nested_attributes_for :items, reject_if: :all_blank

    attribute :confirmed, :boolean

    validates :date, :merchant, :purpose, :signer_name, presence: true
    validates :merchant, :signer_name, length: { maximum: 255 }
    validates :confirmed, acceptance: { accept: true, allow_nil: false }, if: :new_record?
    validates :receipt, presence: true, unless: -> { validation_context == :statement_details }
    validates :items, length: { minimum: 1, maximum: 50 }
    validate :date_is_not_in_the_future

    # Both the web form and API use this operation. Generate and store the PDF
    # before attaching it so storage failures cannot resolve the missing receipt.
    def submit(receiptable:)
      return false unless valid?(:statement_details)

      self.confirmed_at = Time.current
      self.receipt = Receipt.new(receiptable:, user: submitter, upload_method: :lost_receipt_statement, lost_receipt_statement: self)
      html = ApplicationController.render(template: "lost_receipt/statements/statement", formats: [:pdf], layout: false, assigns: { statement: self })
      pdf = WickedPdf.new.pdf_from_string(html, page_size: "Letter", encoding: "UTF-8", disable_javascript: true)
      io = StringIO.new(pdf)
      # Retain the blob before uploading so even a partial upload can be purged.
      blob = ActiveStorage::Blob.create_after_unfurling!(io:, filename: "lost-receipt-statement.pdf", content_type: "application/pdf")
      blob.upload(io)
      receipt.file.attach(blob)
      self.class.transaction do
        receipt.save!
        save!
      end
      true
    rescue ActiveRecord::RecordInvalid => error
      errors.add(:base, error.record.errors.full_messages.to_sentence)
      false
    rescue RuntimeError, ActiveStorage::Error => error
      Rails.error.report(error)
      errors.add(:base, "The statement could not be created. Please try again.")
      false
    ensure
      blob&.purge if blob && !persisted?
    end

    def total_amount_cents
      items.sum(&:total_amount_cents)
    end

    private

    def date_is_not_in_the_future
      errors.add(:date, "can't be in the future") if date && date > Date.current
    end

  end
end
