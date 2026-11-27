# frozen_string_literal: true

# == Schema Information
#
# Table name: lost_receipt_statements
#
#  id                 :bigint           not null, primary key
#  confirmed_at       :datetime         not null
#  date               :date             not null
#  merchant           :string           not null
#  purpose            :text             not null
#  signer_name        :string           not null
#  total_amount_cents :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  receipt_id         :bigint
#  submitter_id       :bigint
#
# Indexes
#
#  index_lost_receipt_statements_on_receipt_id    (receipt_id) UNIQUE
#  index_lost_receipt_statements_on_submitter_id  (submitter_id)
#
# Foreign Keys
#
#  fk_rails_...  (receipt_id => receipts.id)
#  fk_rails_...  (submitter_id => users.id)
#
module LostReceipt
  # What someone said they bought, saved next to the PDF generated from it.
  class Statement < ApplicationRecord
    CONFIRMATION = "I confirm these details are accurate and that I have made every effort possible to get the receipt."

    # Nil until the PDF has been generated and attached, which happens in the background.
    belongs_to :receipt, optional: true, inverse_of: :lost_receipt_statement
    belongs_to :submitter, class_name: "User", optional: true
    # Item errors come from items_are_valid, which numbers them, rather than Rails' "Items description ..." ones.
    has_many :items, -> { order(:id) }, dependent: :destroy, inverse_of: :statement, validate: false
    # The limit is checked before any item is built so a huge request can't allocate them all.
    accepts_nested_attributes_for :items, reject_if: :all_blank, limit: 50

    attribute :confirmed, :boolean
    # Handed in until the PDF is attached; after that it's whatever the receipt is on.
    attr_writer :receiptable

    # Only once the items are known to be valid numbers.
    before_save { self[:total_amount_cents] = total_amount_cents }

    validates :date, :merchant, :purpose, :signer_name, presence: true
    validates :merchant, :signer_name, length: { maximum: 255 }
    validates :purpose, length: { maximum: 2000 }
    # Not stored, so only checkable when the form is submitted.
    validates :confirmed, acceptance: { accept: true, allow_nil: false }, on: :create
    validates :items, length: { minimum: 1, maximum: 50 }
    validate :date_is_not_in_the_future
    validate :items_are_valid
    validate :total_matches_transaction
    validate :signer_name_matches_account

    # Saves the statement and marks the transaction no/lost right away. The PDF
    # takes a few seconds to render, so it's attached as the receipt by a job.
    def submit(receiptable: self.receiptable)
      self.receiptable = receiptable
      self.confirmed_at = Time.current
      return false unless valid?

      transaction do
        save!
        receipt_target.no_or_lost_receipt!
      end
      AttachPdfJob.perform_later(self, receiptable)
      true
    end

    # Renders the PDF and attaches it to the transaction as its receipt.
    def attach_pdf!(receiptable = self.receiptable)
      return if receipt.present?

      self.receiptable = receiptable

      html = ApplicationController.render(template: "lost_receipt/statements/statement", formats: [:pdf], layout: false, assigns: { statement: self })
      io = StringIO.new(CloudflareBrowserRun.pdf(html))
      # Created before uploading so a partial upload can still be purged.
      blob = ActiveStorage::Blob.create_after_unfurling!(io:, filename: "lost-receipt-statement.pdf", content_type: "application/pdf")
      blob.upload(io)
      receipt = Receipt.new(receiptable: receipt_target, user: submitter, upload_method: :lost_receipt_statement, lost_receipt_statement: self)
      receipt.file.attach(blob)
      # Locked so two statements filed for one transaction can't both attach; the later one is dropped.
      receipt_target.with_lock do
        next destroy! if receipt_target.receipts.lost_receipt_statement.exists?

        # Saving the receipt points this statement at it.
        receipt.save!
      end
    ensure
      blob&.purge if blob && !receipt&.persisted?
    end

    # The PDF never got made: put the transaction back to missing a receipt so they can try again.
    def abandon!(receiptable)
      return if receipt.present?

      self.receiptable = receiptable
      transaction do
        destroy!
        unless receipt_target.receipts.lost_receipt_statement.exists?
          receipt_target.update!(marked_no_or_lost_receipt_at: nil)
          receipt_target.sync_no_or_lost_receipt!
        end
      end
    end

    # The transaction being described.
    def receiptable
      @receiptable || receipt&.receiptable
    end

    def total_amount_cents
      items.sum(&:total_amount_cents)
    end

    # The name the signature has to match. Someone signed in signs as themselves;
    # the emailed link goes to the cardholder. Nil when we know neither.
    def expected_signer_name
      (submitter || receiptable.try(:stripe_cardholder)&.user)&.full_name.presence
    end

    private

    # A transaction's receipts live on its ledger item (#14106).
    def receipt_target
      receiptable.try(:ledger_item) || receiptable
    end

    def date_is_not_in_the_future
      # Tomorrow, because the purchaser's time zone can be ahead of the server's.
      errors.add(:date, "can't be in the future") if date && date > Date.tomorrow
    end

    def signer_name_matches_account
      return if expected_signer_name.nil? || signer_name.blank?
      return if signer_name.squish.casecmp?(expected_signer_name.squish)

      errors.add(:signer_name, "must match the name on your HCB account")
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
