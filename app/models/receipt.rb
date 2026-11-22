# frozen_string_literal: true

# == Schema Information
#
# Table name: receipts
#
#  id                              :bigint           not null, primary key
#  data_extracted                  :boolean          default(FALSE), not null
#  extracted_card_last4_ciphertext :text
#  extracted_currency              :string
#  extracted_date                  :datetime
#  extracted_merchant_name         :string
#  extracted_merchant_url          :string
#  extracted_merchant_zip_code     :string
#  extracted_subtotal_amount_cents :integer
#  extracted_total_amount_cents    :integer
#  suggested_memo                  :string
#  textual_content_bidx            :string
#  textual_content_ciphertext      :text
#  textual_content_source          :integer          default(0)
#  upload_method                   :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  receiptable_id                  :bigint
#  receiptable_type                :string
#  user_id                         :bigint
#
# Indexes
#
#  index_receipts_on_receiptable_type_and_receiptable_id  (receiptable_type,receiptable_id)
#  index_receipts_on_textual_content_bidx                 (textual_content_bidx)
#  index_receipts_on_user_id                              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Receipt < ApplicationRecord
  prepend MemoWise

  has_encrypted :textual_content
  blind_index :textual_content
  has_encrypted :extracted_card_last4

  monetize :extracted_subtotal_amount_cents, as: "extracted_subtotal_amount", with_model_currency: :extracted_currency, allow_nil: true
  monetize :extracted_total_amount_cents, as: "extracted_total_amount", with_model_currency: :extracted_currency, allow_nil: true

  include StripeAuthorizationsHelper

  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  set_public_id_prefix :rct

  belongs_to :receiptable, polymorphic: true, optional: true, touch: true

  belongs_to :user, class_name: "User", optional: true
  alias_method :uploader, :user
  alias_method :transaction, :receiptable

  has_one :lost_receipt_statement, class_name: "LostReceipt::Statement", dependent: :destroy, inverse_of: :receipt

  # The HCB code of the transaction this receipt is attached to, whether the
  # receiptable is the HCB code itself or the transaction's ledger item. Nil in
  # the receipt bin and on every other kind of receiptable (expenses, payments,
  # canonical transactions). See Receiptable#receipt_hcb_code.
  def hcb_code
    receiptable.try(:receipt_hcb_code)
  end

  has_many :suggested_pairings, dependent: :destroy

  # add a size to this array for it to be preprocessed
  # Receipt#preview first checks to see if a preprocessed
  # variant exists before generating a new one.
  # - @sampoder
  PREPROCESSED_SIZES = ["1024x1024"].freeze

  has_one_attached :file do |attachable|
    PREPROCESSED_SIZES.each do |resize|
      attachable.variant(resize.to_sym, resize:, preprocessed: true)
    end
  end

  validates :file, attached: true, content_type: /(\Aimage\/.*\z|application\/pdf|text\/csv)/
  MAX_FILE_SIZE = 50.megabytes
  validates :file, size: { less_than_or_equal_to: MAX_FILE_SIZE }, if: -> { attachment_changes["file"].present? }
  validates :file, content_type: "application/pdf", if: :lost_receipt_statement?
  # The statement was validated when it was submitted; the name or amount it was checked against may have changed since.
  validate do
    if lost_receipt_statement? && (new_record? || will_save_change_to_upload_method?) && !lost_receipt_statement&.persisted?
      errors.add(:lost_receipt_statement, "must come from the lost receipt form")
    end
    # It describes one transaction; on another it would resolve a charge nobody itemized.
    if lost_receipt_statement? && persisted? && receiptable.present? && (will_save_change_to_receiptable_id? || will_save_change_to_receiptable_type?)
      errors.add(:base, "A lost receipt statement can't be moved to another transaction")
    end
  end

  # A real receipt clears the no/lost mark, unless a lost receipt statement is on file.
  before_create do
    if !lost_receipt_statement? && receiptable&.has_attribute?(:marked_no_or_lost_receipt_at) && !receiptable.receipts.lost_receipt_statement.exists?
      receiptable.update(marked_no_or_lost_receipt_at: nil)
      # An HCB code and its ledger item each keep a copy of the mark; clear both.
      receiptable.try(:sync_no_or_lost_receipt!)
    end
  end

  # A lost receipt statement is what marks the transaction no/lost.
  before_save do
    if lost_receipt_statement? && receiptable&.has_attribute?(:marked_no_or_lost_receipt_at)
      receiptable.update!(marked_no_or_lost_receipt_at: receiptable.marked_no_or_lost_receipt_at || Time.current)
      receiptable.sync_no_or_lost_receipt!
    end
  end

  after_destroy { clear_lost_receipt_marker_without_statement(receiptable) }
  after_update_commit do
    if (previous = previous_receiptable)
      # After the commit, not inside it: saving a second copy of the old receiptable in the same
      # transaction makes Rails skip the deferred touch that recounts the ledger item's receipts.
      clear_lost_receipt_marker_without_statement(previous)
      CardLocking::ReceiptResolution.on_receipt_destroy(self, receiptable: previous)
    end
  end

  SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS = %w[quick_expense email_receipt_bin].freeze

  after_create_commit do
    # Queue async job to extract text from newly upload receipt
    # and to suggest pairings
    unless Receipt::SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS.include?(upload_method.to_s) || lost_receipt_statement?
      # certain interfaces run suggestions synchronously
      # Receipt::ExtractTextualContentJob.perform_later(self)
      # see https://github.com/hackclub/hcb/issues/7123
      Receipt::SuggestPairingsJob.perform_later(self)
    end
  end

  after_commit(on: [:create, :update]) { CardLocking::ReceiptResolution.on_receipt_upsert(self) }
  after_commit(on: :destroy) { CardLocking::ReceiptResolution.on_receipt_destroy(self) }

  validate :has_owner

  enum :upload_method, {
    transaction_page: 0,
    transaction_page_drag_and_drop: 1,
    receipts_page: 2,
    receipts_page_drag_and_drop: 3,
    attach_receipt_page: 4,
    attach_receipt_page_drag_and_drop: 5,
    email_hcb_code: 6,
    receipt_center: 7,
    receipt_center_drag_and_drop: 8,
    api: 9,
    email_receipt_bin: 10,
    sms: 11,
    transfer_create_page: 12,
    expense_report: 13,
    expense_report_drag_and_drop: 14,
    quick_expense: 15,
    transaction_popover: 16,
    transaction_popover_drag_and_drop: 17,
    email_reimbursement: 18,
    sms_reimbursement: 19,
    employee_payment: 20,
    duplicate: 21,
    discord_bot_modal: 22,
    payment_page: 23,
    contractor_invoice: 24,
    payment_page_drag_and_drop: 25,
    lost_receipt_statement: 26
  }

  enum :textual_content_source, {
    pdf_text: 0,
    tesseract_ocr_text: 1
  }

  scope :in_receipt_bin, -> { where(receiptable: nil) }

  def url
    Rails.application.routes.url_helpers.rails_blob_url(file)
  end

  # Memoized because views call this several times per receipt, and each call
  # looks up (or generates) the variant / preview record.
  memo_wise def preview(resize: "1024x1024", only_path: true)
    if file.previewable?
      Rails.application.routes.url_helpers.rails_representation_url(file.preview(resize:).processed, only_path:)
    elsif file.variable?
      Rails.application.routes.url_helpers.rails_representation_url(
        (resize.in?(PREPROCESSED_SIZES) ? file.variant(resize.to_sym) : file.variant(resize:)).processed, only_path:
      )
    end
  rescue
    # Occasionally ImageMagick has issues that cause images to not be converted.
    # In these cases, we can't guarantee that the browser can render these image types.
    # But we can try? Because otherwise we render nothing.
    # View https://github.com/hackclub/hcb/issues/8551 for more context.
    # - @sampoder
    if file.content_type.start_with?("image/")
      begin
        Rails.application.routes.url_helpers.rails_representation_url(file, only_path:)
      rescue
        nil
      end
    end
  end

  def extract_textual_content
    textual_content_source = if file.content_type == "application/pdf"
                               :pdf_text
                             elsif file.content_type.starts_with?("image")
                               :tesseract_ocr_text
                             else
                               return { text: nil, textual_content_source: nil }
                             end

    text = self.send(textual_content_source) || ""

    { text: text.strip, textual_content_source: }
  rescue => e
    # "ArgumentError: string contains null byte" is a known error
    unless e.is_a?(ArgumentError) && e.message.include?("string contains null byte")
      Rails.error.report(e, context: { receipt_id: id })
    end

    # Since text extraction can be a resource intensive operation, saving an
    # empty string indicates that no text was able to be extracted. This
    # prevents the text extraction from being unintentionally attempted again.
    { text: "", textual_content_source: nil }
  end

  def extract_textual_content!
    extract_textual_content.tap do |result|
      update!(textual_content: result[:text], textual_content_source: result[:textual_content_source])
    end
  end

  def has_textual_content?
    !!(textual_content || extract_textual_content!)
  end

  def extracted_incorrect_amount_cents?
    if receiptable.respond_to?(:amount_cents) && extracted_total_amount_cents
      return extracted_total_amount_cents.abs != receiptable.amount_cents.abs
    end

    false
  end

  def extracted_incorrect_merchant?
    if hcb_code&.stripe_merchant && extracted_merchant_name
      return WhiteSimilarity.similarity(humanized_merchant_name(hcb_code.stripe_merchant), extracted_merchant_name) < 0.5
    end

    false
  end

  def self.reupload(old_receiptable:, new_receiptable:)
    where(receiptable: old_receiptable).find_each do |receipt|
      ::ReceiptService::Create.new(
        receiptable: new_receiptable,
        uploader: receipt.user,
        attachments: [receipt.file.blob],
        upload_method: :duplicate,
      ).run!
    end
  end

  def duplicated?
    if receiptable
      return Receipt.where.not(receiptable_type:, receiptable_id:)
                    .where.not(receiptable_id: nil)
                    .where.not(textual_content: nil)
                    .where(textual_content:).any?
    end

    false
  end

  def duplicates
    if receiptable
      return Receipt.where.not(receiptable_type:, receiptable_id:)
                    .where.not(receiptable_id: nil)
                    .where.not(textual_content: nil)
                    .where(textual_content:)
    end

    Receipt.none
  end

  private

  def previous_receiptable
    return unless saved_change_to_receiptable_id? || saved_change_to_receiptable_type?

    receiptable_type_before_last_save&.constantize&.find_by(id: receiptable_id_before_last_save)
  end

  def clear_lost_receipt_marker_without_statement(record)
    return unless record&.has_attribute?(:marked_no_or_lost_receipt_at) && !record.receipts.lost_receipt_statement.exists?

    record.update!(marked_no_or_lost_receipt_at: nil)
    record.sync_no_or_lost_receipt!
  end

  def pdf_text
    doc = if self.attachment_changes["file"]&.attachable
            Poppler::Document.new(File.read(self.attachment_changes["file"].attachable))
          else
            Poppler::Document.new(file.download)
          end

    doc.pages.map(&:text).join(" ")
  end

  def tesseract_ocr_text
    file.blob.open do |tempfile|
      words = ::RTesseract.new(ImageProcessing::MiniMagick.source(tempfile.path).convert!("png").path).to_box
      words = words.select { |w| w[:confidence] > 85 }
      words = words.map { |w| w[:word] }
      text = words.join(" ")
      text.length > 50 ? text : nil
    end
  end

  def has_owner
    if user.nil? && receiptable.nil?
      errors.add(:base, "must belong to a user, a transaction, or both.")
    end

  end

end
