# frozen_string_literal: true

# == Schema Information
#
# Table name: fees
#
#  id                         :bigint           not null, primary key
#  amount_cents_as_decimal    :decimal(, )
#  event_sponsorship_fee      :decimal(, )
#  reason                     :text
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  canonical_event_mapping_id :bigint           not null
#
# Indexes
#
#  index_fees_on_canonical_event_mapping_id  (canonical_event_mapping_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_event_mapping_id => canonical_event_mappings.id)
#
class Fee < ApplicationRecord
  has_paper_trail

  belongs_to :canonical_event_mapping
  has_one :canonical_transaction, through: :canonical_event_mapping

  validates :reason, presence: true
  validates :amount_cents_as_decimal, numericality: { greater_than_or_equal_to: 0 }
  validates :event_sponsorship_fee, numericality: { greater_than_or_equal_to: 0 }

  scope :greater_than_0, -> { where("amount_cents_as_decimal > 0") }
  scope :exclude_free_events, -> { where("event_sponsorship_fee > 0") }
  scope :exclude_outflows, -> { where("canonical_transactions.amount_cents > 0") }
  scope :exclude_outflows, -> { includes(canonical_event_mapping: :canonical_transaction).where("canonical_transactions.amount_cents > 0").references(canonical_event_mapping: :canonical_transaction) }

  delegate :date, :memo, :smart_memo, :amount, :amount_cents, to: :canonical_transaction

  enum :reason, {
    revenue: "REVENUE",                     # (Charges fee) Normal revenue
    donation_refunded: "DONATION REFUNDED", # (Doesn't charge fee) Donation refunds
    hack_club_fee: "HACK CLUB FEE",         # (Doesn't charge fee) HCB fee transactions
    revenue_waived: "REVENUE WAIVED",       # (Doesn't charge fee) Revenue transactions with fee waived (either manually or automatically in certain cases)
    tbd: "TBD",                             # (Doesn't charge fee) Everything else (including non-revenue transactions)
  }

  def amount_decimal
    amount_cents_as_decimal / 100.0
  end

  def anomaly?
    amount_cents_as_decimal > 0 && canonical_transaction.likely_waveable_for_fee?
  end

end
