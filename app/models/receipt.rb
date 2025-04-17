# frozen_string_literal: true

# == Schema Information
#
# Table name: receipts
#
#  id                              :bigint           not null, primary key
#  data_extracted                  :boolean          default(FALSE), not null
#  extracted_card_last4_ciphertext :text
#  extracted_date                  :datetime
#  extracted_merchant_name         :string
#  extracted_merchant_url          :string
#  extracted_merchant_zip_code     :string
#  extracted_subtotal_amount_cents :integer
#  extracted_total_amount_cents    :integer
#  receiptable_type                :string
#  suggested_memo                  :string
#  textual_content_bidx            :string
#  textual_content_ciphertext      :text
#  textual_content_source          :integer          default("pdf_text")
#  upload_method                   :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  receiptable_id                  :bigint
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
  has_encrypted :textual_content
  blind_index :textual_content
  has_encrypted :extracted_card_last4

  include StripeAuthorizationsHelper

  include PublicIdentifiable
  set_public_id_prefix :rct

  belongs_to :receiptable, polymorphic: true, optional: true, touch: true

  belongs_to :user, class_name: "User", optional: true
  alias_method :uploader, :user
  alias_method :transaction, :receiptable

  has_many :suggested_pairings, dependent: :destroy
  has_many :suggested_transactions, source: :hcb_code, through: :suggested_pairings

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

  before_create do
    if receiptable&.has_attribute?(:marked_no_or_lost_receipt_at)
      receiptable&.update(marked_no_or_lost_receipt_at: nil)
    end
  end

  SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS = %w[quick_expense].freeze

  after_create_commit do
    # Queue async job to extract text from newly upload receipt
    # and to suggest pairings
    unless Receipt::SYNCHRONOUS_SUGGESTION_UPLOAD_METHODS.include?(upload_method.to_s)
      # certain interfaces run suggestions synchronously
      # Receipt::ExtractTextualContentJob.perform_later(self)
      # see https://github.com/hackclub/hcb/issues/7123
      Receipt::SuggestPairingsJob.perform_later(self)
    end
  end
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
    employee_payment: 20
  }

  enum :textual_content_source, {
    pdf_text: 0,
    tesseract_ocr_text: 1
  }

  scope :in_receipt_bin, -> { where(receiptable: nil) }

  def url
    Rails.application.routes.url_helpers.rails_blob_url(file)
  end

  def preview(resize: "1024x1024", only_path: true)
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
    if receiptable.try(:stripe_merchant) && extracted_merchant_name
      return WhiteSimilarity.similarity(humanized_merchant_name(receiptable.stripe_merchant), extracted_merchant_name) < 0.5
    end

    false
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
