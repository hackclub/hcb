# frozen_string_literal: true

# == Schema Information
#
# Table name: ledgers
#
#  id            :bigint           not null, primary key
#  primary       :boolean          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  card_grant_id :bigint
#  event_id      :bigint
#
# Indexes
#
#  index_ledgers_on_card_grant_id   (card_grant_id)
#  index_ledgers_on_event_id        (event_id)
#  index_ledgers_on_id_and_primary  (id,primary) UNIQUE
#  index_ledgers_unique_card_grant  (card_grant_id) UNIQUE WHERE (card_grant_id IS NOT NULL)
#  index_ledgers_unique_event       (event_id) UNIQUE WHERE (event_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (card_grant_id => card_grants.id)
#  fk_rails_...  (event_id => events.id)
#
class Ledger < ApplicationRecord
  self.table_name = "ledgers"

  include Hashid::Rails
  has_paper_trail

  # Possible owners for a primary ledger
  belongs_to :event, optional: true
  belongs_to :card_grant, optional: true
  validate :validate_owner_based_on_primary

  has_many :mappings, class_name: "Ledger::Mapping"
  has_many :items, through: :mappings, source: :ledger_item, class_name: "Ledger::Item"

  has_many :canonical_transactions, through: :items
  has_many :canonical_pending_transactions, through: :items

  monetize def balance_cents = items.sum(:amount_cents)
  monetize def available_balance_cents = items.sum(:amount_cents) - fronted_fee_balance_cents

  def can_front_balance?
    event&.can_front_balance? || card_grant&.event&.can_front_balance? || false
  end

  def receipt_required?
    event&.plan&.receipt_required? || card_grant&.event&.plan&.receipt_required?
  end

  def refresh_all!
    items.find_each do |item|
      item.refresh!
    end
  end

  def fronted_fee_balance_cents
    return 0 if event.nil?

    feed_fronted_pts = canonical_pending_transactions
                       .incoming
                       .fronted
                       .not_waived
                       .not_declined

    feed_fronted_balance = sum_fronted_amount(feed_fronted_pts)

    (event.fees.sum(:amount_cents_as_decimal) - total_fee_payments_cents + (feed_fronted_balance * BigDecimal(event.revenue_fee))).ceil
  end

  def total_fee_payments_cents
    @total_fee_payments_cents ||=
      begin
        paid = canonical_transactions.includes(:fee).where(fee: { reason: "HACK CLUB FEE" }).sum(:amount_cents)
        in_transit = canonical_pending_transactions.bank_fee.unsettled.sum(:amount_cents)

        (paid + in_transit) * -1
      end
  end

  def sum_fronted_amount(pts)
    pt_sum_by_ledger_item = pts.group(:ledger_item).sum(:amount_cents)
    ledger_items = pt_sum_by_ledger_item.keys

    ct_sum_by_ledger_item = canonical_transactions.where(ledger_item: ledger_items)
                                                  .group(:ledger_item)
                                                  .sum(:amount_cents)

    pt_sum_by_ledger_item.reduce 0 do |sum, (ledger_item, pt_sum)|
      sum + [pt_sum - (ct_sum_by_ledger_item[ledger_item] || 0), 0].max
    end
  end

  private

  def validate_owner_based_on_primary
    if primary?
      # Primary ledger must have exactly one owner
      if event_id.nil? && card_grant_id.nil?
        errors.add(:base, "Primary ledger must have an owner (event or card grant)")
      end

      if event_id.present? && card_grant_id.present?
        errors.add(:base, "Primary ledger cannot have more than one owner")
      end
    else
      # Non-primary ledger must not have any owners
      if event_id.present? || card_grant_id.present?
        errors.add(:base, "Non-primary ledger cannot have an owner")
      end
    end
  end

end
