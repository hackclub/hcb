# frozen_string_literal: true

# == Schema Information
#
# Table name: lost_receipt_statements
#
#  id                 :bigint           not null, primary key
#  confirmed_at       :datetime         not null
#  date               :date             not null
#  items              :jsonb            not null
#  merchant           :string           not null
#  purpose            :text             not null
#  signer_name        :string           not null
#  total_amount_cents :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  event_id           :bigint
#  receipt_id         :bigint           not null
#  submitter_id       :bigint
#
# Indexes
#
#  index_lost_receipt_statements_on_event_id      (event_id)
#  index_lost_receipt_statements_on_receipt_id    (receipt_id) UNIQUE
#  index_lost_receipt_statements_on_submitter_id  (submitter_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (receipt_id => receipts.id)
#  fk_rails_...  (submitter_id => users.id)
#
module LostReceipt
  # What someone said they bought, saved next to the PDF generated from it.
  class Statement < ApplicationRecord
    CONFIRMATION = "I confirm these details are accurate and that I have made every effort possible to get the receipt."

    belongs_to :receipt, inverse_of: :lost_receipt_statement
    belongs_to :event, optional: true
    belongs_to :submitter, class_name: "User", optional: true

    # The transaction being described. Not stored: the receipt records where it's attached.
    attr_accessor :receiptable

    attribute :confirmed, :boolean

    # Only once the items are known to be valid numbers.
    before_save { self[:total_amount_cents] = total_amount_cents }

    validates :date, :merchant, :purpose, :signer_name, presence: true
    validates :merchant, :signer_name, length: { maximum: 255 }
    validates :confirmed, acceptance: { accept: true, allow_nil: false }
    validates :items, length: { minimum: 1, maximum: 50 }
    validate :date_is_not_in_the_future
    validate :items_are_valid
    validate :total_matches_transaction
    validate :signer_name_matches_account

    def items_attributes=(attributes)
      attributes = attributes.values if attributes.is_a?(Hash)
      # Checked before building items so a huge request can't allocate them all.
      raise ActiveRecord::NestedAttributes::TooManyRecords if attributes.size > 50

      self.items = attributes.reject { |item| item.values.all?(&:blank?) }.map { |item| Item.new(item) }
    end

    # Stored as JSON, used as Items.
    def items
      @items ||= Array(self[:items]).map { |item| Item.new(item) }
    end

    def items=(items)
      @items = items
      self[:items] = items.map { |item| { description: item.description, quantity: Integer(item.quantity, exception: false) || item.quantity, unit_amount_cents: item.unit_amount_cents } }
    end

    # The receipt is only saved once the PDF is stored, so a failed render or
    # upload leaves the transaction missing its receipt.
    def submit(receiptable: self.receiptable)
      self.receiptable = receiptable
      self.event = receiptable.try(:event)
      self.confirmed_at = Time.current
      # A transaction's receipts live on its ledger item (#14106). Saving the receipt saves this statement.
      self.receipt = Receipt.new(receiptable: receiptable.try(:ledger_item) || receiptable, user: submitter, upload_method: :lost_receipt_statement, lost_receipt_statement: self)
      return false unless valid?

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

    # The name the signature has to match. Someone signed in signs as themselves;
    # the emailed link goes to the cardholder. Nil when we know neither.
    def expected_signer_name
      (submitter || receiptable.try(:stripe_cardholder)&.user)&.full_name.presence
    end

    private

    def date_is_not_in_the_future
      errors.add(:date, "can't be in the future") if date && date > Date.current
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
