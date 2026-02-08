# frozen_string_literal: true

# == Schema Information
#
# Table name: bank_fees
#
#  id             :bigint           not null, primary key
#  aasm_state     :string
#  amount_cents   :integer
#  hcb_code       :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :bigint           not null
#  fee_revenue_id :bigint
#
# Indexes
#
#  index_bank_fees_on_event_id        (event_id)
#  index_bank_fees_on_fee_revenue_id  (fee_revenue_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class BankFee < ApplicationRecord
  has_paper_trail

  include AASM
  include HasBookTransfer

  include PublicIdentifiable
  set_public_id_prefix :bfe

  belongs_to :event
  belongs_to :fee_revenue, optional: true

  monetize :amount_cents

  after_create :set_hcb_code

  scope :since_feature_launch, -> { where("created_at > ?", Time.utc(2021, 5, 20)) }
  scope :in_transit_or_confirmed, -> { where("aasm_state in (?)", ["confirmed", "in_transit"]) }

  aasm do
    state :pending, initial: true
    state :confirmed
    state :in_transit
    state :settled

    event :mark_confirmed do
      transitions from: :pending, to: :confirmed
    end

    event :mark_in_transit do
      transitions from: :confirmed, to: :in_transit
    end

    event :mark_settled do
      transitions from: :in_transit, to: :settled
    end
  end

  after_create_commit :create_raw_pending_bank_fee_transaction_and_cpt
  after_commit :update_canonical_pending_transaction_amount

  def state
    return :success if settled?
    return :info if in_transit?

    :muted
  end

  def state_text
    return "Settled" if settled?
    return "Paid & Settling" if in_transit?

    "Pending"
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_pending_transaction
    canonical_pending_transactions.first
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= begin
      return [] unless raw_pending_bank_fee_transaction.present?

      ::CanonicalPendingTransaction.where(raw_pending_bank_fee_transaction_id: raw_pending_bank_fee_transaction.id)
    end
  end

  private

  def set_hcb_code
    self.update_column(:hcb_code, "HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE}-#{id}")
  end

  def raw_pending_bank_fee_transaction
    raw_pending_bank_fee_transactions.first
  end

  def raw_pending_bank_fee_transactions
    @raw_pending_bank_fee_transactions ||= ::RawPendingBankFeeTransaction.where(bank_fee_transaction_id: id)
  end

  def create_raw_pending_bank_fee_transaction_and_cpt
    rpt = ::RawPendingBankFeeTransaction.find_or_initialize_by(bank_fee_transaction_id: id.to_s).tap do |t|
      t.amount_cents = amount_cents
      t.date_posted = created_at
    end
    rpt.save!

    attrs = {
      date: rpt.date,
      memo: rpt.memo,
      amount_cents: rpt.amount_cents,
      raw_pending_bank_fee_transaction_id: rpt.id,
      fronted: rpt.amount_cents.positive?,
      fee_waived: true
    }
    ::CanonicalPendingTransaction.create!(attrs)
  end

  def update_canonical_pending_transaction_amount
    return unless canonical_pending_transaction.present?

    canonical_pending_transaction.update!(amount_cents: amount_cents)
  end

end
