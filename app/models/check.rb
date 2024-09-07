# frozen_string_literal: true

# == Schema Information
#
# Table name: checks
#
#  id                     :bigint           not null, primary key
#  aasm_state             :string
#  amount                 :integer
#  approved_at            :datetime
#  check_number           :integer
#  description_ciphertext :text
#  expected_delivery_date :datetime
#  exported_at            :datetime
#  lob_url                :text
#  memo                   :text
#  payment_for            :text
#  refunded_at            :datetime
#  rejected_at            :datetime
#  send_date              :datetime
#  transaction_memo       :string
#  voided_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  creator_id             :bigint
#  lob_address_id         :bigint
#  lob_id                 :string
#
# Indexes
#
#  index_checks_on_creator_id      (creator_id)
#  index_checks_on_lob_address_id  (lob_address_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (lob_address_id => lob_addresses.id)
#
class Check < ApplicationRecord
  has_paper_trail skip: [:description] # ciphertext columns will still be tracked
  has_encrypted :description

  include PublicIdentifiable
  set_public_id_prefix :chk

  include AASM
  include Commentable

  include PgSearch::Model
  pg_search_scope :search_recipient, associated_against: { lob_address: :name, event: :name }, against: [:memo], using: { tsearch: { prefix: true, dictionary: "english" } }, ranked_by: "checks.created_at"

  belongs_to :creator, class_name: "User"
  belongs_to :lob_address
  has_one :event, through: :lob_address

  accepts_nested_attributes_for :lob_address

  has_many :t_transactions, class_name: "Transaction", inverse_of: :check

  validates :amount, numericality: { greater_than: 0, message: "must be greater than 0" }
  validates :send_date, presence: true
  validate :send_date_must_be_in_future, on: :create

  scope :in_transit_or_in_transit_and_processed, -> { where("aasm_state in (?)", ["in_transit", "in_transit_and_processed"]) }

  aasm do
    state :scheduled, initial: true
    state :in_transit
    state :in_transit_and_processed
    state :deposited
    state :canceled
    state :voided
    state :refunded

    state :rejected # deprecate
    state :approved # deprecate
    state :pending # deprecate
    state :pending_void # deprecate

    event :mark_canceled do
      transitions from: :scheduled, to: :canceled
    end

    event :mark_in_transit do
      transitions from: :scheduled, to: :in_transit
    end

    event :mark_in_transit_and_processed do
      transitions from: :in_transit, to: :in_transit_and_processed
    end

    event :mark_deposited do
      transitions from: [:in_transit, :in_transit_and_processed], to: :deposited
    end

    event :mark_refunded do
      transitions to: :refunded
    end

    event :mark_voided do
      transitions to: :voided
    end
  end

  def pending_expired?
    local_hcb_code.has_pending_expired?
  end

  def can_cancel?
    scheduled? # only scheduled checks can be canceled (not yet created on lob)
  end

  def state_text
    status.to_s.humanize
  end

  def name
    @name ||= lob_address.name
  end

  # DEPRECATE
  def status
    aasm_state.to_sym
  end

  def status_text
    case status
    when :scheduled, :created
      "Scheduled"
    when :in_transit, :in_transit_and_processed
      "In Transit"
    when :canceled, :rejected
      "Canceled"
    else
      status.to_s.humanize
    end
  end

  def state
    case status
    when :scheduled, :created
      "pending"
    when :in_transit, :in_transit_and_processed
      "info"
    when :deposited
      "success"
    when :canceled, :rejected, :voided
      "muted"
    else
      "info"
    end
  end


  def self.refunded_but_needs_match
    select { |check| check.refunded_at.present? && check.t_transactions.size != 4 }
  end

  # Can be ready to refund
  def pending_void?
    approved? && voided_at.present? && !deposited? && !voided?
  end

  # Ready to be refunded
  def unfinished_void?
    !refunded_at.present? && voided_at && voided_at + 1.day < DateTime.now && !deposited?
  end

  # Refunded & needs refund transactions attached
  def refunded_but_needs_match?
    refunded_at.present? && t_transactions != 4
  end

  # Void requested & check deposited before it could go through
  def failed_void?
    approved? && voided_at.present? && t_transactions.size == 3 && t_transactions.sum(&:amount) < 0
  end

  def state_icon
    "checkmark" if deposited?
  end

  def admin_dropdown_description
    "#{check_number.present? ? check_number : 'No number'} | #{event.name} | #{lob_address.name} | #{status} - #{ApplicationController.helpers.render_money amount}"
  end

  def sent?
    send_date.past?
  end

  def url
    lob_url
  end

  def smart_memo
    lob_address.try(:name).try(:upcase)
  end

  def hcb_code
    "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE}-#{id}"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= ::CanonicalPendingTransaction.where(hcb_code:)
  end

  def recipient_name
    lob_address.name
  end

  private

  def send_date_must_be_in_future
    self.errors.add(:send_date, "must be at least 24 hours in the future") if send_date.nil? || send_date <= (Time.now.utc + 24.hours)
  end

end
