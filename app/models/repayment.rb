# frozen_string_literal: true

# One instance of paying back expenses, funded either by one disbursement
# (another organization pays the expense back) or by money that came in on the
# same ledger and was marked as paying it back (e.g. a check from whoever owed
# it).
# == Schema Information
#
# Table name: repayments
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  created_by_id           :bigint
#  disbursement_id         :bigint
#  repaying_ledger_item_id :bigint
#
# Indexes
#
#  index_repayments_on_created_by_id            (created_by_id)
#  index_repayments_on_disbursement_id          (disbursement_id) UNIQUE
#  index_repayments_on_repaying_ledger_item_id  (repaying_ledger_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (disbursement_id => disbursements.id)
#  fk_rails_...  (repaying_ledger_item_id => ledger_items.id)
#
# Check Constraints
#
#  repayments_disbursement_or_repaying_ledger_item  (num_nonnulls(disbursement_id, repaying_ledger_item_id) = 1)
#
class Repayment < ApplicationRecord
  # Both sides on the recipient's ledger reduce expenses instead of counting
  # the incoming repayment as revenue.
  CATEGORY_SLUG = "repayment"

  # Donations and invoices are revenue, not money paid back. Incoming
  # transfers are only allowed by repaying_ledger_items.
  NON_REPAYING_LINKED_OBJECT_TYPES = ["Disbursement::Outgoing", "Disbursement::Incoming", "Donation", "Invoice"].freeze

  has_paper_trail

  belongs_to :disbursement, optional: true, inverse_of: :repayment
  belongs_to :repaying_ledger_item, class_name: "Ledger::Item", optional: true, inverse_of: :repaying_repayment
  belongs_to :created_by, class_name: "User", optional: true
  has_many :allocations, class_name: "Repayment::Allocation", inverse_of: :repayment, dependent: :destroy, autosave: true
  has_many :repaid_ledger_items, through: :allocations

  # Rejected and errored disbursements never moved money, so they don't count.
  # Repayments by a ledger item have no disbursement to fail.
  scope :not_failed, -> { left_joins(:disbursement).where("disbursements.id IS NULL OR disbursements.aasm_state NOT IN (?)", ["rejected", "errored"]) }

  validates :disbursement_id, uniqueness: true, allow_nil: true
  validates :repaying_ledger_item, uniqueness: { message: "has already been marked as a repayment" }, allow_nil: true
  validates :allocations, presence: true
  validate :funded_by_a_disbursement_or_a_ledger_item
  validate :disbursement_is_a_repayment
  validate :ledger_items_are_unique
  # Ledger item amounts can change later (e.g. a partial refund), so these are
  # only checked when the repayment is made.
  validate :repaying_transaction_is_money_in_on_the_same_ledger, on: :create, if: :repaying_ledger_item
  validate :allocations_match_repaying_amount, on: :create, if: :repaying_ledger_item

  def self.repayable_ledger_items(event) = Allocation.repayable_ledger_items(event)
  def self.unrepaid_ledger_items(event) = Allocation.unrepaid_ledger_items(event)

  # Settled money in on the organization's ledger that could have paid an
  # expense back. Pending money in can still change amount or never arrive.
  def self.repaying_ledger_items(event, user = nil)
    # A plain transfer from another organization that should have been sent
    # as a repayment can be marked as one once it has settled. Repayment
    # transfers already have their own repayment.
    #
    # Marking one also moves the expense onto the sender's books, so only
    # someone who manages the sender can do it. Otherwise the income would
    # leave the recipient's revenue without the sender taking on the expense.
    markable_transfers = Disbursement.where(transfer_type: [nil, "transfer"], source_subledger_id: nil, destination_subledger_id: nil)
                                     .where.not(source_event_id: event.id)
    markable_transfers = markable_transfers.none if user.nil?
    markable_transfers = markable_transfers.where(source_event_id: user.manageable_events.select(:id)) unless user.nil? || user.admin?

    event.ledger.items
         .where(status: :settled)
         .where("ledger_items.amount_cents > 0")
         .where(
           "ledger_items.linked_object_type IS NULL OR ledger_items.linked_object_type NOT IN (?) OR (ledger_items.linked_object_type = 'Disbursement::Incoming' AND ledger_items.linked_object_id IN (?))",
           NON_REPAYING_LINKED_OBJECT_TYPES, markable_transfers.select(:id)
         )
         .not_likely_account_verification_related
  end

  # Money in that hasn't already been marked as repaying something.
  def self.unused_repaying_ledger_items(event, user = nil)
    repaying_ledger_items(event, user).where.not(id: where.not(repaying_ledger_item_id: nil).select(:repaying_ledger_item_id))
  end

  # What a ledger item could be marked as a repayment with: for an unrepaid
  # expense, unused money in of the same amount; for unused money in,
  # unrepaid expenses of the same amount. Transfers are only offered to a
  # user who manages their sender.
  def self.match_candidates(ledger_item, user = nil)
    event = ledger_item.primary_ledger&.event
    return Ledger::Item.none if event.nil?

    own, others = if ledger_item.amount_cents.negative?
                    [unrepaid_ledger_items(event), unused_repaying_ledger_items(event, user)]
                  else
                    [unused_repaying_ledger_items(event, user), unrepaid_ledger_items(event)]
                  end
    return Ledger::Item.none unless own.exists?(ledger_item.id)

    others.where(amount_cents: -ledger_item.amount_cents)
  end

  # The organization whose expenses were repaid.
  def event
    disbursement&.destination_event || repaying_ledger_item&.primary_ledger&.event
  end

  # A transfer's incoming side is categorized when it's created, so only a
  # repaying ledger item has transactions to categorize here.
  def repaying_transactions = transactions_of(repaying_ledger_item)

  # The transfer whose incoming side was marked as the repayment, if any.
  def repaying_transfer
    repaying_ledger_item.linked_object.disbursement if repaying_ledger_item&.linked_object_type == "Disbursement::Incoming"
  end

  # The sending organization's side of that transfer, which takes on the
  # expense's category (see Allocation).
  def sender_transactions = transactions_of(repaying_transfer&.outgoing_disbursement&.ledger_item)

  def revert_categories!
    allocations.each(&:revert_categories!)
  end

  private

  def transactions_of(ledger_item)
    return [] if ledger_item.nil?

    [
      *ledger_item.canonical_transactions.includes(category_mapping: :category),
      *ledger_item.canonical_pending_transactions.includes(category_mapping: :category)
    ]
  end

  def funded_by_a_disbursement_or_a_ledger_item
    errors.add(:base, "must be funded by either a transfer or a transaction") unless disbursement.present? ^ repaying_ledger_item.present?
  end

  # The event comes from the repaying item's ledger, so this also keeps both
  # sides on the same ledger.
  def repaying_transaction_is_money_in_on_the_same_ledger
    unless event && Repayment.repaying_ledger_items(event, created_by).exists?(repaying_ledger_item.id)
      errors.add(:repaying_ledger_item, "must be settled money in on an organization's ledger")
    end
  end

  def allocations_match_repaying_amount
    unless allocations.sum { |allocation| allocation.amount_cents.to_i } == repaying_ledger_item.amount_cents
      errors.add(:allocations, "must add up to the amount of the repaying transaction")
    end
  end

  # The disbursement checks that the allocations add up to its amount.
  def disbursement_is_a_repayment
    errors.add(:disbursement, "must be a repayment") unless disbursement.nil? || disbursement.transfer_type_repayment?
  end

  def ledger_items_are_unique
    ids = allocations.reject(&:marked_for_destruction?).map(&:ledger_item_id)
    errors.add(:allocations, "must include each expense only once") if ids.uniq.size != ids.size
  end

end
