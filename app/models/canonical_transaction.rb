# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer          not null
#  custom_memo             :text
#  date                    :date             not null
#  friendly_memo           :text
#  hcb_code                :text
#  memo                    :text             not null
#  transaction_source_type :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  transaction_source_id   :bigint
#
# Indexes
#
#  index_canonical_transactions_on_date                (date)
#  index_canonical_transactions_on_hcb_code            (hcb_code)
#  index_canonical_transactions_on_transaction_source  (transaction_source_type,transaction_source_id)
#
class CanonicalTransaction < ApplicationRecord
  has_paper_trail

  include Receiptable

  include PgSearch::Model
  pg_search_scope :search_memo, against: [:memo, :friendly_memo, :custom_memo, :hcb_code], using: { tsearch: { any_word: true, prefix: true, dictionary: "english" } }, ranked_by: "canonical_transactions.date"
  pg_search_scope :pg_text_search, lambda { |query, options_hash| { query: }.merge(options_hash) }

  scope :unmapped, -> { includes(:canonical_event_mapping).where(canonical_event_mappings: { canonical_transaction_id: nil }) }
  scope :mapped, -> { includes(:canonical_event_mapping).where.not(canonical_event_mappings: { canonical_transaction_id: nil }) }
  scope :missing_pending, -> { includes(:canonical_pending_settled_mapping).where(canonical_pending_settled_mappings: { canonical_transaction_id: nil }) }
  scope :has_pending, -> { includes(:canonical_pending_settled_mapping).where.not(canonical_pending_settled_mappings: { canonical_transaction_id: nil }) }
  scope :missing_hcb_code, -> { where(hcb_code: nil) }
  scope :missing_or_unknown_hcb_code, -> { where("hcb_code is null or hcb_code ilike 'HCB-000%'") }
  scope :invoice_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}%'") }
  scope :bank_fee_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE}%'") }
  scope :donation_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE}%'") }
  scope :ach_transfer_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE}%'") }
  scope :check_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE}%'") }
  scope :disbursement_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DISBURSEMENT_CODE}%'") }
  scope :stripe_card_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}%'") }
  scope :with_custom_memo, -> { where("custom_memo is not null") }
  scope :without_custom_memo, -> { where("custom_memo is null") }
  scope :with_short_code, -> { where("memo ~ '.*HCB-\\w{5}.*'") }

  scope :revenue, -> { where("amount_cents > 0") }
  scope :expense, -> { where("amount_cents < 0") }

  scope :increase_transaction, -> { joins("INNER JOIN raw_increase_transactions ON transaction_source_type = 'RawIncreaseTransaction' AND raw_increase_transactions.id = transaction_source_id") }
  scope :stripe_transaction,   -> { joins("INNER JOIN raw_stripe_transactions   ON transaction_source_type = 'RawStripeTransaction'   AND raw_stripe_transactions.id   = transaction_source_id") }
  scope :emburse_transaction,  -> { joins("INNER JOIN raw_emburse_transactions  ON transaction_source_type = 'RawEmburseTransaction'  AND raw_emburse_transactions.id  = transaction_source_id") }
  scope :column_transaction,   -> { joins("INNER JOIN raw_column_transactions   ON transaction_source_type = 'RawColumnTransaction'   AND raw_column_transactions.id  =  transaction_source_id") }

  scope :likely_hack_club_bank_issued_cards, -> { where("memo ilike 'Hack Club Bank Issued car%' or memo ilike 'HCKCLB Issued car%' or memo ilike 'STRIPE Issued car%'") }
  scope :likely_clearing_checks, -> { where("memo ilike '%Withdrawal - Inclearing Check #%' or memo ilike '%Withdrawal - On-Us Deposited Ite #%'") }
  scope :likely_checks, -> { where("memo ilike '%Check TO ACCOUNT REDACTED'") }
  scope :likely_increase_checks, -> { increase_transaction.where("raw_increase_transactions.increase_transaction->'source'->>'category' = 'check_transfer_intention'") }
  scope :likely_disbursements, -> { where("memo ilike 'HCB DISBURSE%'") }
  scope :likely_achs, -> { where("memo ilike '%BUSBILLPAY%'") }
  scope :likely_increase_achs, -> { increase_transaction.where("raw_increase_transactions.increase_transaction->'source'->>'category' = 'ach_transfer_intention'") }
  scope :likely_increase_account_number, -> { increase_transaction.joins("INNER JOIN increase_account_numbers ON increase_account_number_id = increase_route_id") }
  scope :likely_increase_check_deposit, -> { increase_transaction.where("raw_increase_transactions.increase_transaction->'source'->>'category' = 'check_deposit_acceptance'") }
  scope :increase_interest, -> { increase_transaction.where("raw_increase_transactions.increase_transaction->'source'->>'category' = 'interest_payment'") }
  scope :likely_column_interest, -> {
    column_transaction.where("raw_column_transactions.column_transaction->>'transaction_type' = 'interest.payout.completed'")
                      .or(where(memo: "COLUMN*COLUMN NA INTEREST"))
  }
  scope :likely_column_account_number, -> { column_transaction.joins("INNER JOIN column_account_numbers ON column_transaction->>'account_number_id' = column_account_numbers.column_id") }
  scope :likely_hack_club_fee, -> { where("memo ilike '%Hack Club Bank Fee TO ACCOUNT%'") }
  scope :old_likely_hack_club_fee, -> { where("memo ilike '% Fee TO ACCOUNT REDACTED%'") }
  scope :stripe_top_up, -> { where("memo ilike '%Hack Club Bank Stripe Top%' or memo ilike '%HACKC Stripe Top%' or memo ilike '%HCKCLB Stripe Top%' or memo ilike '%STRIPE Stripe Top%'") }
  scope :not_stripe_top_up, -> { where("(memo not ilike '%Hack Club Bank Stripe Top%' and memo not ilike '%HACKC Stripe Top%' and memo not ilike '%HCKCLB Stripe Top%' and memo not ilike '%STRIPE Stripe Top%') or memo is null") }
  scope :hcb_sweep, -> { where("memo ilike '%COLUMN*THE HACK HCB-SWEEP%'") }
  scope :to_svb_sweep_account, -> { where(memo: "TF TO ICS SWP") }
  scope :from_svb_sweep_account, -> { where(memo: "TF FRM ICS SWP") }
  scope :svb_sweep_account, -> { where(transaction_source_type: RawIntrafiTransaction.name) }
  scope :svb_sweep_interest, -> { where(transaction_source_type: RawIntrafiTransaction.name, memo: "Interest Capitalization") }
  scope :mapped_by_human, -> { includes(:canonical_event_mapping).where("canonical_event_mappings.user_id is not null").references(:canonical_event_mapping) }
  scope :included_in_stats, -> {
    includes(
      canonical_event_mapping: { event: :plan }
    ).where.not(
      event_plans: {
        type: Event::Plan.that(:omit_stats).collect(&:name)
      }
    )
  }

  scope :with_column_transaction_type, ->(type) { column_transaction.where("raw_column_transactions.column_transaction->>'transaction_type' LIKE ?", "#{sanitize_sql_like(type)}%") }

  monetize :amount_cents

  has_many :canonical_hashed_mappings
  has_many :hashed_transactions, through: :canonical_hashed_mappings
  has_one :canonical_event_mapping
  has_one :event, through: :canonical_event_mapping
  has_one :canonical_pending_settled_mapping
  has_one :canonical_pending_transaction, through: :canonical_pending_settled_mapping
  has_one :local_hcb_code, foreign_key: "hcb_code", primary_key: "hcb_code", class_name: "HcbCode"
  has_one :fee, through: :canonical_event_mapping

  belongs_to :transaction_source, polymorphic: true, optional: true

  attr_writer :fee_payment, :hashed_transaction, :stripe_cardholder, :raw_stripe_transaction

  validates :friendly_memo, presence: true, allow_nil: true
  validates :custom_memo, presence: true, allow_nil: true

  before_validation { self.custom_memo = custom_memo.presence&.strip }

  after_create :write_hcb_code
  after_create_commit :write_system_event
  after_create_commit do
    if likely_stripe_card_transaction?
      PendingEventMappingEngine::Settle::Single::Stripe.new(canonical_transaction: self).run
      EventMappingEngine::Map::Single::Stripe.new(canonical_transaction: self).run
    end
  end

  def smart_memo
    custom_memo || less_smart_memo
  end

  def less_smart_memo
    # friendly_memo || friendly_memo_in_memory_backup
    # Prevent reading 'friendly_memo' from DB while patching #2670
    friendly_memo_in_memory_backup
  end

  def likely_disbursement?
    memo.to_s.upcase.include?("HCB DISBURSE")
  end

  def likely_hack_club_fee?
    hcb_code.starts_with?("HCB-700-") || memo.to_s.upcase.include?("HACK CLUB BANK FEE TO ACCOUNT")
  end

  def likely_check_clearing_dda?
    memo.to_s.upcase.include?("FROM DDA#80007609524 ON")
  end

  def likely_card_transaction_refund?
    likely_stripe_card_transaction? && amount_cents > 0
  end

  def likely_stripe_card_transaction?
    transaction_source_type == RawStripeTransaction.name
  end

  def linked_object
    @linked_object ||= TransactionEngine::SyntaxSugarService::LinkedObject.new(canonical_transaction: self).run
  end

  def raw_plaid_transaction
    transaction_source if transaction_source_type == RawPlaidTransaction.name
  end

  def raw_emburse_transaction
    transaction_source if transaction_source_type == RawEmburseTransaction.name
  end

  def raw_stripe_transaction
    @raw_stripe_transaction ||= begin
      transaction_source if transaction_source_type == RawStripeTransaction.name
    end
  end

  def raw_increase_transaction
    transaction_source if transaction_source_type == RawIncreaseTransaction.name
  end

  def raw_column_transaction
    transaction_source if transaction_source_type == RawColumnTransaction.name
  end

  def column_transaction_type
    raw_column_transaction&.transaction_type
  end

  def column_transaction_id
    raw_column_transaction&.transaction_id
  end

  def bank_account_name
    transaction_source.try(:bank_account_name) || transaction_source_type[/Raw(.+)Transaction/, 1]
  end

  def stripe_cardholder
    @stripe_cardholder ||= begin
      return nil unless raw_stripe_transaction

      ::StripeCardholder.find_by(stripe_id: raw_stripe_transaction.stripe_transaction["cardholder"])
    end
  end

  def stripe_card
    @stripe_card ||= begin
      return nil unless raw_stripe_transaction

      ::StripeCard.find_by(stripe_id: raw_stripe_transaction.stripe_transaction["card"])
    end
  end

  def emburse_card
    @emburse_card ||= begin
      return nil unless raw_emburse_transaction

      ::EmburseCard.find_by(emburse_id: raw_emburse_transaction.emburse_transaction.dig("card", "id"))
    end
  end

  def stripe_refund?
    raw_stripe_transaction&.refund?
  end

  def raw_pending_stripe_transaction
    nil
  end

  def remote_stripe_iauth_id
    return nil unless raw_stripe_transaction

    raw_stripe_transaction.stripe_transaction["authorization"]
  end

  def stripe_auth_dashboard_url
    return nil unless remote_stripe_iauth_id

    "https://dashboard.stripe.com/issuing/authorizations/#{remote_stripe_iauth_id}"
  end

  def likely_waveable_for_fee?
    likely_check_clearing_dda? ||
      likely_card_transaction_refund? ||
      likely_disbursement?
  end

  # DEPRECATED
  def marked_no_or_lost_receipt_at=(v)
    v
  end

  def marked_no_or_lost_receipt_at
    nil
  end

  def receipt_required?
    false
  end

  def display_name # in deprecated system this is the renamed transaction name
    smart_memo
  end

  def name # in deprecated system this is the imported name
    memo
  end

  def filter_data
    {} # TODO
  end

  def fee_payment?
    return @fee_payment if defined?(@fee_payment)

    @fee_payment ||= fee&.hack_club_fee?
  end

  def invoice
    return linked_object if linked_object.is_a?(Invoice)

    nil
  end

  def bank_fee
    return linked_object if linked_object.is_a?(BankFee)

    nil
  end

  def reimbursement_expense_payout
    return linked_object if linked_object.is_a?(Reimbursement::ExpensePayout)

    nil
  end

  def reimbursement_payout_holding
    return linked_object if linked_object.is_a?(Reimbursement::PayoutHolding)

    nil
  end

  def invoice_payout
    return linked_object.payout if linked_object.is_a?(Invoice)

    nil
  end

  def fee_reimbursement
    return linked_object.fee_reimbursement if linked_object.is_a?(Donation) || linked_object.is_a?(Invoice)

    nil
  end

  def check
    return linked_object if linked_object.is_a?(Check)

    nil
  end

  def increase_check
    return linked_object if linked_object.is_a?(IncreaseCheck)

    nil
  end

  def paypal_transfer
    return linked_object if linked_object.is_a?(PaypalTransfer)
  end

  def wire
    return linked_object if linked_object.is_a?(Wire)
  end

  def check_deposit
    return linked_object if linked_object.is_a?(CheckDeposit)

    nil
  end

  def ach_transfer
    return linked_object if linked_object.is_a?(AchTransfer)

    nil
  end

  def likely_ach_confirmation_number
    memo.match(/BUSBILLPAY TRAN#(\d+)/)&.[](1)
  end

  def likely_account_verification_related?
    hcb_code.starts_with?("HCB-000-") && memo.downcase.include?("acctverify") && amount_cents.abs < 100
  end

  def short_code
    memo[/HCB-(\w{5})/, 1]
  end

  def donation
    donation_payout.try(:donation)
  end

  def donation_payout
    return linked_object.payout if linked_object.is_a?(Donation)

    nil
  end

  def fee_applies?
    @fee_applies ||= fee.present? && fee.amount_cents_as_decimal > 0
  end

  def emburse_transfer
    nil # TODO
  end

  def disbursement
    return linked_object if linked_object.is_a?(Disbursement)

    nil
  end

  def unique_bank_identifier
    @unique_bank_identifier ||= transaction_source.try(:unique_bank_identifier)
  end

  def memo_hcb_code_likely_donation?
    memo.include?("HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE}")
  end

  def memo_hcb_code_likely_invoice?
    memo.include?("HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}")
  end

  def write_hcb_code
    safely do
      code = ::TransactionGroupingEngine::Calculate::HcbCode.new(canonical_transaction_or_canonical_pending_transaction: self).run

      self.update_column(:hcb_code, code)

      ::HcbCodeService::FindOrCreate.new(hcb_code: code).run
    end
  end

  private

  def hashed_transaction
    @hashed_transaction ||= begin
      Airbrake.notify("There was less than 1 hashed_transaction for canonical_transaction: #{self.id}") if hashed_transactions.size < 1
      Airbrake.notify("There was more than 1 hashed_transaction for canonical_transaction: #{self.id}") if hashed_transactions.size > 1

      hashed_transactions.first
    end
  end

  def friendly_memo_in_memory_backup
    @friendly_memo_in_memory_backup ||= TransactionEngine::FriendlyMemoService::Generate.new(canonical_transaction: self).run
  end

  def write_system_event
    safely do
      ::SystemEventService::Write::SettledTransactionCreated.new(canonical_transaction: self).run
    end
  end

end
