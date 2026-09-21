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
# Check Constraints
#
#  ledgers_owner_rules  ("primary" IS TRUE AND (event_id IS NOT NULL AND card_grant_id IS NULL OR event_id IS NULL AND card_grant_id IS NOT NULL) OR "primary" IS FALSE AND event_id IS NULL AND card_grant_id IS NULL)
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
  has_many :pinned_mappings, -> { pinned }, class_name: "Ledger::Mapping", inverse_of: :ledger
  has_many :items, through: :mappings, source: :ledger_item, class_name: "Ledger::Item"
  has_many :pinned_items, through: :pinned_mappings, source: :ledger_item, class_name: "Ledger::Item"

  has_many :canonical_transactions, through: :items
  has_many :canonical_pending_transactions, through: :items

  monetize def balance_cents(start_date: nil, end_date: nil)
    query_items(start_date:, end_date:).sum(:amount_cents)
  end

  monetize def revenue_cents = query_items(amount: { "$gt": 0 }).sum(:amount_cents)

  # The fiscal sponsorship fee accrues as revenue arrives but only lands on the
  # ledger once it's charged, so the fee that's still pending is an expense
  # that hasn't happened yet — the same amount the ledger renders as a pending
  # "Fiscal sponsorship" row, and the same amount available_balance_cents holds
  # back, which keeps revenue - expenses == available balance. A negative fee
  # balance is a fee credit, not an expense, hence the floor at zero.
  monetize def expenses_cents = query_items(amount: { "$lt": 0 }).sum(:amount_cents).abs + [fronted_fee_balance_cents, 0].max

  # A negative fee balance is a fee credit. Credits are not spendable, so
  # they never add to the available balance.
  monetize def available_balance_cents = balance_cents - [fronted_fee_balance_cents, 0].max

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

    @fronted_fee_balance_cents ||=
      begin
        feed_fronted_pts = canonical_pending_transactions
                           .incoming
                           .fronted
                           .not_waived
                           .not_declined

        feed_fronted_balance = sum_fronted_amount(feed_fronted_pts)

        (event.fees.sum(:amount_cents_as_decimal) - total_fee_payments_cents + (feed_fronted_balance * BigDecimal(event.revenue_fee))).ceil
      end
  end

  def fee_balance_cents
    return 0 if event.nil?

    event.fees.sum(:amount_cents_as_decimal).ceil - total_fee_payments_cents
  end

  def total_fee_payments_cents
    return 0 if event.nil?

    @total_fee_payments_cents ||=
      begin
        paid = canonical_transactions.includes(:fee).where(fee: { reason: "HACK CLUB FEE" }).sum(:amount_cents)
        in_transit = canonical_pending_transactions.bank_fee.unsettled.sum(:amount_cents)

        (paid + in_transit) * -1
      end
  end

  def sum_fronted_amount(pts)
    pt_sum_by_ledger_item = pts.group(:ledger_item_id).sum(:amount_cents)
    ledger_items = pt_sum_by_ledger_item.keys

    ct_sum_by_ledger_item = canonical_transactions.where(ledger_item_id: ledger_items)
                                                  .group(:ledger_item_id)
                                                  .sum(:amount_cents)

    pt_sum_by_ledger_item.reduce 0 do |sum, (ledger_item, pt_sum)|
      sum + [pt_sum - (ct_sum_by_ledger_item[ledger_item] || 0), 0].max
    end
  end

  private

  # Every total goes through Ledger::Query so they all count the same set of
  # items as the balance does.
  def query_items(start_date: nil, end_date: nil, amount: nil)
    Ledger::Query.new({
                        "$and": [
                          ({ datetime: { "$gte": start_date } } if start_date),
                          ({ datetime: { "$lte": end_date } } if end_date),
                          ({ amount_cents: amount } if amount)
                        ].compact
                      }).execute(ledgers: [self])
  end

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
