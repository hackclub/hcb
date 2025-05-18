# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_transactions
#
#  id                                               :bigint           not null, primary key
#  amount_cents                                     :integer          not null
#  custom_memo                                      :text
#  date                                             :date             not null
#  fee_waived                                       :boolean          default(FALSE)
#  fronted                                          :boolean          default(FALSE)
#  hcb_code                                         :text
#  memo                                             :text             not null
#  created_at                                       :datetime         not null
#  updated_at                                       :datetime         not null
#  check_deposit_id                                 :bigint
#  increase_check_id                                :bigint
#  paypal_transfer_id                               :bigint
#  raw_pending_bank_fee_transaction_id              :bigint
#  raw_pending_donation_transaction_id              :bigint
#  raw_pending_incoming_disbursement_transaction_id :bigint
#  raw_pending_invoice_transaction_id               :bigint
#  raw_pending_outgoing_ach_transaction_id          :bigint
#  raw_pending_outgoing_check_transaction_id        :bigint
#  raw_pending_outgoing_disbursement_transaction_id :bigint
#  raw_pending_stripe_transaction_id                :bigint
#  reimbursement_expense_payout_id                  :bigint
#  reimbursement_payout_holding_id                  :bigint
#  wire_id                                          :bigint
#
# Indexes
#
#  index_canonical_pending_transactions_on_check_deposit_id         (check_deposit_id)
#  index_canonical_pending_transactions_on_hcb_code                 (hcb_code)
#  index_canonical_pending_transactions_on_increase_check_id        (increase_check_id)
#  index_canonical_pending_transactions_on_paypal_transfer_id       (paypal_transfer_id)
#  index_canonical_pending_transactions_on_wire_id                  (wire_id)
#  index_canonical_pending_txs_on_raw_pending_bank_fee_tx_id        (raw_pending_bank_fee_transaction_id)
#  index_canonical_pending_txs_on_raw_pending_donation_tx_id        (raw_pending_donation_transaction_id)
#  index_canonical_pending_txs_on_raw_pending_invoice_tx_id         (raw_pending_invoice_transaction_id)
#  index_canonical_pending_txs_on_raw_pending_outgoing_ach_tx_id    (raw_pending_outgoing_ach_transaction_id)
#  index_canonical_pending_txs_on_raw_pending_outgoing_check_tx_id  (raw_pending_outgoing_check_transaction_id)
#  index_canonical_pending_txs_on_raw_pending_stripe_tx_id          (raw_pending_stripe_transaction_id)
#  index_canonical_pending_txs_on_reimbursement_expense_payout_id   (reimbursement_expense_payout_id)
#  index_canonical_pending_txs_on_reimbursement_payout_holding_id   (reimbursement_payout_holding_id)
#  index_cpts_on_raw_pending_incoming_disbursement_transaction_id   (raw_pending_incoming_disbursement_transaction_id)
#  index_cpts_on_raw_pending_outgoing_disbursement_transaction_id   (raw_pending_outgoing_disbursement_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (raw_pending_stripe_transaction_id => raw_pending_stripe_transactions.id)
#
class CanonicalPendingTransaction < ApplicationRecord
  has_paper_trail

  include PgSearch::Model
  pg_search_scope :search_memo, against: [:memo, :custom_memo, :hcb_code], using: { tsearch: { any_word: true, prefix: true, dictionary: "english" } }, ranked_by: "canonical_pending_transactions.date"
  pg_search_scope :pg_text_search, lambda { |query, options_hash| { query: }.merge(options_hash) }

  belongs_to :raw_pending_stripe_transaction, optional: true
  validates_uniqueness_of :raw_pending_stripe_transaction_id, allow_nil: true

  belongs_to :raw_pending_outgoing_check_transaction, optional: true
  belongs_to :raw_pending_outgoing_ach_transaction, optional: true
  belongs_to :raw_pending_donation_transaction, optional: true
  belongs_to :raw_pending_invoice_transaction, optional: true
  belongs_to :raw_pending_bank_fee_transaction, optional: true
  belongs_to :raw_pending_incoming_disbursement_transaction, optional: true
  belongs_to :raw_pending_outgoing_disbursement_transaction, optional: true
  belongs_to :increase_check, optional: true
  belongs_to :paypal_transfer, optional: true
  belongs_to :wire, optional: true
  belongs_to :check_deposit, optional: true
  belongs_to :reimbursement_expense_payout, class_name: "Reimbursement::ExpensePayout", optional: true
  belongs_to :reimbursement_payout_holding, class_name: "Reimbursement::PayoutHolding", optional: true

  has_one :canonical_pending_event_mapping
  has_one :event, through: :canonical_pending_event_mapping
  has_one :subledger, through: :canonical_pending_event_mapping
  has_many :canonical_pending_settled_mappings
  has_many :canonical_transactions, through: :canonical_pending_settled_mappings
  has_one :canonical_pending_declined_mapping
  has_one :local_hcb_code, foreign_key: "hcb_code", primary_key: "hcb_code", class_name: "HcbCode"

  monetize :amount_cents

  scope :safe, -> { where("date >= '2021-01-01'") } # older pending transactions don't yet all map up because of older processes (especially around invoices)

  scope :stripe, -> { where("raw_pending_stripe_transaction_id is not null") }
  scope :incoming, -> { where(CanonicalPendingTransaction.arel_table[:amount_cents].gt(0)) }
  scope :outgoing, -> { where(CanonicalPendingTransaction.arel_table[:amount_cents].lt(0)) }
  scope :outgoing_ach, -> { where("raw_pending_outgoing_ach_transaction_id is not null") }
  scope :outgoing_check, -> { where("raw_pending_outgoing_check_transaction_id is not null") }
  scope :increase_check, -> { where.not(increase_check_id: nil) }
  scope :wire, -> { where.not(wire: nil) }
  scope :check_deposit, -> { where.not(check_deposit_id: nil) }
  scope :donation, -> { where("raw_pending_donation_transaction_id is not null") }
  scope :invoice, -> { where("raw_pending_invoice_transaction_id is not null") }
  scope :bank_fee, -> { where("raw_pending_bank_fee_transaction_id is not null") }
  scope :incoming_disbursement, -> { where("raw_pending_incoming_disbursement_transaction_id is not null") }
  scope :outgoing_disbursement, -> { where("raw_pending_outgoing_disbursement_transaction_id is not null") }
  scope :reimbursement_expense_payout, -> { where.not(reimbursement_expense_payout_id: nil) }
  scope :reimbursement_payout_holding, -> { where.not(reimbursement_payout_holding_id: nil) }
  scope :unmapped, -> { includes(:canonical_pending_event_mapping).where(canonical_pending_event_mappings: { canonical_pending_transaction_id: nil }) }
  scope :mapped, -> { includes(:canonical_pending_event_mapping).where.not(canonical_pending_event_mappings: { canonical_pending_transaction_id: nil }) }
  scope :unsettled, -> {
    includes(:canonical_pending_settled_mappings)
      .where(canonical_pending_settled_mappings: { canonical_pending_transaction_id: nil })
      .includes(:canonical_pending_declined_mapping)
      .where(canonical_pending_declined_mapping: { canonical_pending_transaction_id: nil })
  }
  scope :missing_hcb_code, -> { where(hcb_code: nil) }
  scope :missing_or_unknown_hcb_code, -> { where("hcb_code is null or hcb_code ilike 'HCB-000%'") }
  scope :invoice_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}%'") }
  scope :donation_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE}%'") }
  scope :ach_transfer_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE}%'") }
  scope :check_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE}%'") }
  scope :disbursement_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DISBURSEMENT_CODE}%'") }
  scope :stripe_card_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}%'") }
  scope :bank_fee_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE}%'") }
  scope :fronted, -> { where(fronted: true) }
  scope :not_fronted, -> { where(fronted: false) }
  scope :not_declined, -> { includes(:canonical_pending_declined_mapping).where(canonical_pending_declined_mapping: { canonical_pending_transaction_id: nil }) }
  scope :not_waived, -> { where(fee_waived: false) }
  scope :included_in_stats, -> {
    includes(
      canonical_pending_event_mapping: { event: :plan }
    ).where.not(
      event_plans: {
        type: Event::Plan.that(:omit_stats).collect(&:name)
      }
    )
  }
  scope :with_custom_memo, -> { where("custom_memo is not null") }

  scope :pending_expired, -> { unsettled.where(created_at: ..5.days.ago) }

  validates :custom_memo, presence: true, allow_nil: true

  before_validation { self.custom_memo = custom_memo.presence&.strip }

  after_create :write_hcb_code
  after_create_commit :write_system_event

  attr_writer :stripe_cardholder

  def pending_expired?
    unsettled? && created_at < 5.days.ago
  end

  def mapped?
    @mapped ||= canonical_pending_event_mapping.present?
  end

  def settled?
    @settled ||= canonical_pending_settled_mappings.present?
  end

  def decline!
    return false if declined?

    create_canonical_pending_declined_mapping!
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def declined?
    @declined ||= canonical_pending_declined_mapping.present?
  end

  def stripe_decline_reason
    raw_pending_stripe_transaction&.stripe_transaction&.dig("request_history", 0, "reason")&.to_sym
  end

  def hcb_decline_reason
    raw_pending_stripe_transaction&.stripe_transaction&.dig("metadata", "declined_reason")&.to_sym
  end

  def decline_reason
    hcb_decline_reason || stripe_decline_reason
  end

  def declined_by
    hcb_decline_reason ? "HCB" : "Stripe"
  end

  def unsettled?
    @unsettled ||= !settled? && !declined?
  end

  def fronted_amount
    return 0 if !fronted || self.amount_cents.negative? || declined?

    pts = local_hcb_code.canonical_pending_transactions
                        .includes(:canonical_pending_event_mapping)
                        .where(canonical_pending_event_mapping: { event_id: event.id, subledger_id: subledger&.id })
                        .where(fronted: true)
                        .order(date: :asc, id: :asc)
    pts_sum = pts.map(&:amount_cents).sum
    return 0 if pts_sum.negative?

    cts_sum = local_hcb_code.canonical_transactions
                            .includes(:canonical_event_mapping)
                            .where(canonical_event_mapping: { event_id: event.id, subledger_id: subledger&.id })
                            .sum(&:amount_cents)

    # PTs that were chronologically created first in an HcbCode are first
    # responsible for "contributing" to the fronted amount. After a PT's
    # amount_cents is fully allocated to the fronted amount, the next
    # chronological PT in the hcb_code is responsible for allocating it's own
    # amount_cents towards the fronted amount.
    #
    # The code below is a simplified implementation of that "algorithm".

    prior_pt_sum = pts.reduce(0) do |sum, pt|
      # Sum until this PT (inclusive)
      sum += pt.amount_cents
      break sum if pt.id == self.id
    end
    residual = prior_pt_sum - cts_sum

    if residual.positive?
      [residual, amount_cents].min
    else
      0
    end
  end

  def smart_memo
    custom_memo || friendly_memo
  end

  def friendly_memo
    friendly_memo_in_memory_backup
  end

  def linked_object
    return raw_pending_outgoing_check_transaction.check if raw_pending_outgoing_check_transaction
    return raw_pending_outgoing_ach_transaction.ach_transfer if raw_pending_outgoing_ach_transaction
    return raw_pending_donation_transaction.donation if raw_pending_donation_transaction
    return raw_pending_invoice_transaction.invoice if raw_pending_invoice_transaction
    return raw_pending_bank_fee_transaction.bank_fee if raw_pending_bank_fee_transaction
    return raw_pending_incoming_disbursement_transaction.disbursement if raw_pending_incoming_disbursement_transaction
    return raw_pending_outgoing_disbursement_transaction.disbursement if raw_pending_outgoing_disbursement_transaction

    nil
  end

  def disbursement
    return linked_object if linked_object.is_a?(Disbursement)

    nil
  end

  def ach_transfer
    return linked_object if linked_object.is_a?(AchTransfer)

    nil
  end

  def check
    return linked_object if linked_object.is_a?(Check)

    nil
  end

  def invoice
    return linked_object if linked_object.is_a?(Invoice)

    nil
  end

  def bank_fee
    return linked_object if linked_object.is_a?(BankFee)

    nil
  end

  def donation
    return linked_object if linked_object.is_a?(Donation)

    nil
  end

  def raw_stripe_transaction
    nil # used by canonical_transaction. necessary to implement as nil given hcb code generation
  end

  def remote_stripe_iauth_id
    return nil unless raw_pending_stripe_transaction

    raw_pending_stripe_transaction.stripe_transaction_id
  end

  def stripe_auth_dashboard_url
    return nil unless remote_stripe_iauth_id

    "https://dashboard.stripe.com/issuing/authorizations/#{remote_stripe_iauth_id}"
  end

  # DEPRECATED
  def display_name
    smart_memo
  end

  def name # in deprecated system this is the imported name
    smart_memo
  end

  def filter_data
    {} # TODO
  end

  def comments
    [] # TODO
  end

  def fee_payment?
    false # TODO
  end

  def invoice_payout
    nil # TODO
  end

  def fee_reimbursement
    nil # TODO
  end

  def donation_payout
    nil # TODO
  end

  def fee_applies?
    nil # TODO
  end

  def emburse_transfer
    nil # TODO
  end

  def url
    return "/hcb/#{local_hcb_code.hashid}" if local_hcb_code

    "/canonical_pending_transactions/#{id}"
  end

  def stripe_cardholder
    @stripe_cardholder ||= begin
      return nil unless raw_pending_stripe_transaction

      ::StripeCardholder.find_by(stripe_id: raw_pending_stripe_transaction.stripe_transaction["cardholder"])
    end
  end

  def stripe_card
    @stripe_card ||= begin
      return nil unless raw_pending_stripe_transaction

      ::StripeCard.find_by(stripe_id: raw_pending_stripe_transaction.stripe_transaction["card"]["id"])
    end
  end

  private

  def write_hcb_code
    safely do
      code = ::TransactionGroupingEngine::Calculate::HcbCode.new(canonical_transaction_or_canonical_pending_transaction: self).run

      self.update_column(:hcb_code, code)

      ::HcbCodeService::FindOrCreate.new(hcb_code: code).run
    end
  end

  def friendly_memo_in_memory_backup
    @friendly_memo_in_memory_backup ||= PendingTransactionEngine::FriendlyMemoService::Generate.new(pending_canonical_transaction: self).run
  end

  def write_system_event
    safely do
      ::SystemEventService::Write::PendingTransactionCreated.new(canonical_pending_transaction: self).run
    end
  end

end
