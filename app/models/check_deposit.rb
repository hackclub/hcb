# frozen_string_literal: true

# == Schema Information
#
# Table name: check_deposits
#
#  id               :bigint           not null, primary key
#  amount_cents     :integer
#  increase_status  :string
#  rejection_reason :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  back_file_id     :string
#  column_id        :string
#  created_by_id    :bigint           not null
#  event_id         :bigint           not null
#  front_file_id    :string
#  increase_id      :string
#
# Indexes
#
#  index_check_deposits_on_created_by_id  (created_by_id)
#  index_check_deposits_on_event_id       (event_id)
#  index_check_deposits_on_increase_id    (increase_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class CheckDeposit < ApplicationRecord
  has_paper_trail

  REJECTION_DESCRIPTIONS = {
    "incomplete_image"                => "This check was rejected because the photo was incomplete.",
    "duplicate"                       => "This check was rejected as a duplicate.",
    "poor_image_quality"              => "This check was rejected due to poor image quality.",
    "incorrect_amount"                => "This check was rejected because the amount was incorrect.",
    "incorrect_recipient"             => "This check was rejected because the recipient was incorrect.",
    "not_eligible_for_mobile_deposit" => "This check is not eligible for mobile deposit.",
  }.freeze

  monetize :amount_cents

  belongs_to :event
  belongs_to :created_by, class_name: "User"
  has_one :canonical_pending_transaction

  after_create_commit :submit!

  after_update if: -> { increase_status_previously_changed?(to: "rejected") } do
    canonical_pending_transaction.decline!
    CheckDepositMailer.with(check_deposit: self).rejected.deliver_later
  end

  after_update if: -> { increase_status_previously_changed?(to: "deposited") } do
    CheckDepositMailer.with(check_deposit: self).deposited.deliver_later
  end

  has_one_attached :front
  has_one_attached :back

  validates :amount_cents, numericality: { greater_than: 0, message: "can't be zero!" }, presence: true
  validates :front, attached: true, processable_image: true
  validates :back, attached: true, processable_image: true
  validates_uniqueness_of :column_id, allow_nil: true

  scope :unprocessed, -> { where(increase_id: nil, column_id: nil) }

  enum :increase_status, {
    pending: "pending", # when check deposit created
    submitted: "submitted", # when ProcessColumnCheckDepositJob runs successfully
    manual_submission_required: "manual_submission_required", # when ProcessColumnCheckDepositJob fails
    rejected: "rejected", # if an admin can't manually submit it.
    returned: "returned",
    deposited: "deposited"
  }, default: :pending

  alias_attribute :status, :increase_status

  enum :rejection_reason, {
    incomplete_image: "incomplete_image",
    duplicate: "duplicate",
    poor_image_quality: "poor_image_quality",
    incorrect_amount: "incorrect_amount",
    incorrect_recipient: "incorrect_recipient",
    not_eligible_for_mobile_deposit: "not_eligible_for_mobile_deposit",
    unknown: "unknown"
  }, prefix: :rejection_reason

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  def submit!
    ProcessColumnCheckDepositJob.perform_later(check_deposit: self)

    create_canonical_pending_transaction!(event:, amount_cents:, memo: "CHECK DEPOSIT", date: created_at)
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::CHECK_DEPOSIT_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def state
    return :muted if column_id.nil? && increase_id.nil?
    return :success if local_hcb_code.ct.present?

    if pending? || manual_submission_required?
      :info
    elsif rejected? || returned?
      :error
    elsif deposited? || local_hcb_code.ct.present?
      :success
    elsif submitted?
      :info
    end
  end

  def state_text
    if pending? || manual_submission_required?
      "Processing"
    elsif rejected?
      "Rejected"
    elsif returned?
      "Returned"
    elsif deposited? || local_hcb_code.ct.present?
      "Deposited"
    elsif submitted?
      "Submitted"
    end
  end

  def rejection_description
    REJECTION_DESCRIPTIONS[rejection_reason] || "This check deposit was rejected."
  end

  def self.rejection_descriptions
    REJECTION_DESCRIPTIONS
  end

  def submitted_to_column_at
    return unless column_id.present?

    @submitted_to_column_at ||= versions.where_object_changes_from(column_id: nil).first&.created_at
  end

  def estimated_arrival_date
    estimated = submitted_to_column_at&.+(1.week)&.to_date
    return nil if estimated.nil?
    return nil if Date.today >= estimated

    estimated
  end

end
