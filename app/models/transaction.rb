# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id                             :bigint           not null, primary key
#  amount                         :bigint
#  date                           :date
#  deleted_at                     :datetime
#  display_name                   :text
#  is_event_related               :boolean
#  location_address               :text
#  location_city                  :text
#  location_lat                   :decimal(, )
#  location_lng                   :decimal(, )
#  location_state                 :text
#  location_zip                   :text
#  name                           :text
#  payment_meta_by_order_of       :text
#  payment_meta_payee             :text
#  payment_meta_payer             :text
#  payment_meta_payment_method    :text
#  payment_meta_payment_processor :text
#  payment_meta_reason            :text
#  payment_meta_reference_number  :text
#  pending                        :boolean
#  slug                           :text
#  transaction_type               :text
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ach_transfer_id                :bigint
#  bank_account_id                :bigint
#  check_id                       :bigint
#  disbursement_id                :bigint
#  donation_payout_id             :bigint
#  emburse_transfer_id            :bigint
#  fee_reimbursement_id           :bigint
#  fee_relationship_id            :bigint
#  invoice_payout_id              :bigint
#  payment_meta_ppd_id            :text
#  pending_transaction_id         :text
#  plaid_category_id              :text
#  plaid_id                       :text
#
# Indexes
#
#  index_transactions_on_ach_transfer_id       (ach_transfer_id)
#  index_transactions_on_bank_account_id       (bank_account_id)
#  index_transactions_on_check_id              (check_id)
#  index_transactions_on_deleted_at            (deleted_at)
#  index_transactions_on_disbursement_id       (disbursement_id)
#  index_transactions_on_donation_payout_id    (donation_payout_id)
#  index_transactions_on_emburse_transfer_id   (emburse_transfer_id)
#  index_transactions_on_fee_reimbursement_id  (fee_reimbursement_id)
#  index_transactions_on_fee_relationship_id   (fee_relationship_id)
#  index_transactions_on_invoice_payout_id     (invoice_payout_id)
#  index_transactions_on_plaid_id              (plaid_id) UNIQUE
#  index_transactions_on_slug                  (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ach_transfer_id => ach_transfers.id)
#  fk_rails_...  (bank_account_id => bank_accounts.id)
#  fk_rails_...  (check_id => checks.id)
#  fk_rails_...  (disbursement_id => disbursements.id)
#  fk_rails_...  (donation_payout_id => donation_payouts.id)
#  fk_rails_...  (emburse_transfer_id => emburse_transfers.id)
#  fk_rails_...  (fee_reimbursement_id => fee_reimbursements.id)
#  fk_rails_...  (fee_relationship_id => fee_relationships.id)
#  fk_rails_...  (invoice_payout_id => invoice_payouts.id)
#
class Transaction < ApplicationRecord
  include Receiptable
  extend FriendlyId

  paginates_per 250

  friendly_id :slug_text, use: :slugged

  acts_as_paranoid

  default_scope { order(date: :desc, id: :desc) }
  scope :uncategorized, -> { where(is_event_related: true, fee_relationship_id: nil) }
  # needs_action is a subset of :uncategorized that needs action TODAY. It excludes
  # FeeReimbursement transactions that will eventually be paired when an Invoice gets paid,
  # but includes FeeReimbursements that have been unpaired for a long time.
  scope :needs_action, -> {
    where(is_event_related: true, fee_relationship_id: nil)
      .select { |t| !t.potential_fee_reimbursement? || t.date < 3.weeks.ago }
  }
  # used by the unified transaction list shown on the event show page
  scope :unified_list, -> { where(fee_reimbursement_id: nil) }
  scope :renamed, -> { where("display_name != name") }

  belongs_to :bank_account

  belongs_to :fee_relationship, inverse_of: :t_transaction, optional: true
  has_one :event, through: :fee_relationship

  belongs_to :emburse_transfer, inverse_of: :t_transaction, optional: true
  belongs_to :invoice_payout, inverse_of: :t_transaction, optional: true

  belongs_to :fee_reimbursement, inverse_of: :t_transaction, optional: true

  belongs_to :check, inverse_of: :t_transactions, optional: true
  belongs_to :ach_transfer, inverse_of: :t_transaction, optional: true
  belongs_to :disbursement, inverse_of: :t_transactions, optional: true

  belongs_to :donation_payout, inverse_of: :t_transaction, optional: true

  accepts_nested_attributes_for :fee_relationship

  validates :plaid_id, uniqueness: true
  validates :is_event_related, inclusion: { in: [true, false] }

  validates :fee_relationship,
            absence: true,
            unless: -> { self.is_event_related }

  validates :amount, numericality: { only_integer: true }

  validate :ensure_paired_correctly

  after_initialize :default_values

  def memo
    name
  end

  def admin_dropdown_description
    "#{name} - #{id}"
  end

  def short_plaid_id
    "#{plaid_id[0...4]}…#{plaid_id[-4..]}"
  end

  delegate :url_helpers, to: "Rails.application.routes"
  def link
    host = Rails.application.config.action_mailer.default_url_options[:host]
    host + url_helpers.transaction_path(self)
  end

  def default_values
    self.is_event_related = true if self.is_event_related.nil?
    self.display_name ||= self.name
  end

  def set_default_display_name
    # used by the migration that adds display names
    self.display_name ||= self.name
  end

  # Utility method for getting the fee on the transaction if there is one. Used
  # in CSV export.
  def fee
    is_event_related && fee_relationship&.fee_applies && fee_relationship.fee_amount
  end

  def fee_payment?
    is_event_related && fee_relationship&.is_fee_payment
  end

  def fee_applies?
    is_event_related && fee_relationship&.fee_applies
  end

  def categorized?
    is_event_related && fee_relationship_id
  end

  def uncategorized?
    is_event_related && fee_relationship_id.nil?
  end

  def filter_data
    {
      exists: true,
      fee_applies: fee_applies?,
      fee_payment: fee_payment?,
      card: false
    }
  end

  def ensure_paired_correctly
    # NOTE: here, we have to compare to fee_relationship&.event and not just event,
    # because fee_relationship is the attribute directly set by a request to update
    # and reflects the most up-to-date value of event, and just "event" is a getter
    # that may be cached for the model and thus incorrect.

    # if linked to an invoice, check that invoice's event is transaction's event
    if !invoice_payout.nil? && invoice_payout.invoice && invoice_payout.invoice.event != fee_relationship&.event
      # NOTE: this extra check ^^^^^^^^^^^^^^^^^^^^^^ is to not break with historical data that
      # no longer correctly conforms to correct schema. (InvoicePayout without Invoice) (TX ID 5467)
      errors.add(:base, "Paired invoice payout's event must match transaction's event")
    end

    # if emburse_transfer linked, check that emburse_transfer's event is transaction's event
    if !emburse_transfer.nil? && emburse_transfer.event != fee_relationship&.event
      errors.add(:base, "Paired emburse transfers's event must match transaction's event")
      return 3
    end
  end

  # The following set of "potential_[ xxx ]?" methods
  # use usually-reliable heuristics to try to guess
  # whether the tx is a certain kind, usually by the tx memo.
  #
  # As noted by the "potential" prefix, these are not reliable,
  # and meant to aid human work.
  #
  # They are used in try_pair_automatically! and rendering Transaction#edit
  #
  # TODO: eventually, we want to move these concerns out to their
  # corresponding models. i.e. potential_donation_payout?
  # should probably be a part of the Donation class, not Transaction.

  def potential_invoice_payout?
    amount.positive? &&
      self.name.start_with?("Hack Club Bank PAYOUT", "HACKC PAYOUT", "HACK CLUB EVENT")

  end

  def potential_donation_payout?
    amount.positive? &&
      self.name.start_with?("Hack Club Bank DONATE", "HACKC DONATE ", "HACK CLUB EVENT")

  end

  # We used to also use 'FEE REIMBURSEMENT' as prefix
  # but is deprecated, so don't look for it anymore.
  def potential_fee_reimbursement?
    self.name.start_with?("FEE REFUND")
  end

  def potential_fee_payment?
    self.name.include?("Bank Fee")
  end

  def potential_emburse?
    self.name.include?("emburse.com")
  end

  # GitHub Grants
  def potential_github?
    self.name.include?("GitHub Grant")
  end

  def potential_expensify?
    self.name.include?("Expensify")
  end

  def potential_ach_transfer?
    self.name.include?("BUSBILLPAY")
  end

  def potential_check?
    # This is a guess from observation, but may not cover 100%
    # of the cases. FRB's transaction memos are weird.
    self.name.include?("DDA#") || self.name.include?("Check")
  end

  def potential_disbursement?
    self.name.start_with?("HCB DISBURSE")
  end

  # Tries to fully pair this transaction successfully
  # re: https://github.com/hackclub/bank/issues/364
  # returns True if paired successfully, false otherwise.
  #
  # NOTE: wrap calls to this in a SQL transaction to avoid
  # broken states.
  def try_pair_automatically!
    return if categorized?

    if potential_fee_reimbursement?
      # try_pair_fee_reimbursement
    elsif potential_donation_payout?
      # try_pair_donation
    elsif potential_fee_payment?
      # try_pair_fee_payment
    elsif potential_invoice_payout?
      try_pair_invoice
    elsif potential_emburse?
      try_pair_emburse
    elsif potential_github?
      # try_pair_github
    elsif potential_ach_transfer?
      # try_pair_ach_transfer
    elsif potential_check?
      # try_pair_check
    elsif potential_disbursement?
      # try_pair_disbursement
    end
    # NOTE: we cannot curently auto-pair Expensify txs
  rescue => e
    Airbrake.notify(e)
  end

  # Tries to recover transaction data from a previously paired / modified
  # transaction that was pending, for a currently complete transaction.
  # This is complicated by the fact that the pending? attribute Plaid
  # returns from SVB is just a big fat lie ~because Plaid hates us~.
  # So every TX shows as complete, and we can't disambiguate in code.
  #
  # This is a workaround for the issue highlighted in GH Issue #443.
  # TL;DR - when a TX goes from pending -> complete, SVB deletes
  # the old TX and creates a new one, but we want to persist our
  # model data between them.
  #
  # NOTE: wrap calls to this in a SQL transaction to avoid
  # broken states.
  def try_recover_pending_tx_details!
    # transactions that were deleted, that match in TX memo, date,
    # and amount, are good candidates for a previously pending TX
    # that is now complete as `self`.
    matching_deleted_tx = Transaction.with_deleted
                                     .where(date: self.date)
                                     .where(amount: self.amount)
                                     .where.not(deleted_at: nil)
                                     .select { |t| self.name.start_with?(t.name) }

    return unless matching_deleted_tx.count == 1

    previous = matching_deleted_tx[0]

    # if for some reason we've found the transaction itself,
    # stop now.
    return if self == previous

    # copy over copyable details

    # copy over old display name only if old one was renamed
    # and new one was not
    if self.display_name == self.name && previous.display_name != previous.name
      self.display_name = previous.display_name
    end

    self.is_event_related = previous.is_event_related
    previous.comments.each do |comment|
      comment.update(commentable_id: self.id)
    end
    pfr = previous.fee_relationship
    if !pfr.nil? # this is only true if previous was paired successfully
      self.fee_relationship = FeeRelationship.new(
        event_id: pfr.event_id,
        fee_applies: pfr.fee_applies,
        fee_amount: pfr.fee_amount,
        is_fee_payment: pfr.is_fee_payment,
      )
    end

    if self.invoice_payout.nil? && previous.invoice_payout
      self.invoice_payout = previous.invoice_payout
      previous.invoice_payout = nil
    end

    if self.donation_payout.nil? && previous.donation_payout
      self.donation_payout = previous.donation_payout
      previous.donation_payout = nil
    end

    if self.emburse_transfer.nil? && previous.emburse_transfer
      self.emburse_transfer = previous.emburse_transfer
      previous.emburse_transfer = nil
    end

    if self.fee_reimbursement.nil? && previous.fee_reimbursement
      self.fee_reimbursement = previous.fee_reimbursement
      previous.fee_reimbursement = nil
    end

    if self.check.nil? && previous.check
      self.check = previous.check
      previous.check = nil
    end

    self.save
    previous.save
  end

  def receipt_required?
    false
  end

  private

  def try_pair_invoice
    return unless potential_invoice_payout?

    # tx name can be one of two forms, from observation:
    # 1. HACKC PAYOUT [PREFIX] ST-XXXXXXXXXX The Hack Foundation
    #   -- if it's a complete TX
    # 2. HACKC PAYOUT [PREFIX]
    #   -- if it's a pending TX
    # where PREFIX appears in InvoicePayout.statement_descriptor as
    #   "PAYOUT [PREFIX]"
    #
    # We should parse out the PREFIX from the TX.name, try to find any matching
    # InvoicePayouts, and match it.

    # case 1
    match = /(?:HACKC|Hack Club Bank) PAYOUT (.*) ST-.*/.match(self.name)
    prefix = match ? match[1] : false
    if !prefix
      # case 2
      match = /(?:HACKC|Hack Club Bank) PAYOUT (.*)/.match(self.name)
      prefix = match ? match[1] : false
    end

    # if we can't find a prefix, bail
    return unless prefix

    # find all payouts that match both amount and statement_descriptor
    payouts_matching_amount = InvoicePayout.lacking_transaction.where(amount: self.amount)
    payouts_matching_prefix = payouts_matching_amount.select { |po|
      po.statement_descriptor.start_with?("PAYOUT #{prefix}")
    }

    # if there's exactly one match, pick that one
    return unless payouts_matching_prefix.count == 1

    payout = payouts_matching_prefix[0]

    # pair the transaction
    self.invoice_payout = payout
    self.fee_relationship = FeeRelationship.new(
      event_id: payout.invoice.event.id,
      fee_applies: true
    )

    self.display_name = "Invoice to #{payout.invoice.sponsor.name}"
    self.save
  end

  def try_pair_donation
    return unless potential_donation_payout?

    # tx name can be one of two forms, from observation:
    # 1. HACKC DONATE [PREFIX] ST-XXXXXXXXXX The Hack Foundation
    #   -- if it's a complete TX
    # 2. HACKC DONATE [PREFIX]
    #   -- if it's a pending TX
    # where PREFIX appears in DonationPayout.statement_descriptor as
    #   "DONATE [PREFIX]"
    #
    # We should parse out the PREFIX from the TX.name, try to find any matching
    # DonationPayouts, and match it.

    # case 1
    match = /(?:HACKC|Hack Club Bank) DONATE (.*) ST-.*/.match(self.name)
    prefix = match ? match[1] : false
    if !prefix
      # case 2
      match = /(?:HACKC|Hack Club Bank) DONATE (.*)/.match(self.name)
      prefix = match ? match[1] : false
    end

    # if we can't find a prefix, bail
    return unless prefix

    # find all payouts that match both amount and statement_descriptor
    payouts_matching_amount = DonationPayout.lacking_transaction.where(amount: self.amount)
    payouts_matching_prefix = payouts_matching_amount.select { |po|
      po.statement_descriptor.start_with?("DONATE #{prefix}")
    }

    # if there's exactly one match, pick that one
    return unless payouts_matching_prefix.count == 1

    payout = payouts_matching_prefix[0]

    # pair the transaction
    self.donation_payout = payout
    self.fee_relationship = FeeRelationship.new(
      event_id: payout.donation.event.id,
      fee_applies: true
    )

    self.display_name = "Donation from #{payout.donation.name}"
    self.save
  end

  def try_pair_fee_reimbursement
    return unless potential_fee_reimbursement?

    FeeReimbursement.pending.each do |reimbursement|
      next unless (self.name.start_with? reimbursement.transaction_memo)
      next unless reimbursement.payout&.t_transaction
      next unless self.amount == reimbursement.amount || reimbursement.amount < 100 && self.amount == 100

      reimbursement.t_transaction = self

      self.fee_relationship = FeeRelationship.new(
        event_id: reimbursement.event.id,
        fee_applies: true,
        fee_amount: reimbursement.calculate_fee_amount
      )

      self.display_name = reimbursement.transaction_display_name
      self.save

      break
    end
  end

  def try_pair_fee_payment
    return unless potential_fee_payment?

    match = /(?!Event )(.*) Bank Fee.*/.match(self.name)
    event_id = match ? match[1].to_i : 0

    return if event_id == 0

    # we don't use Event.find here because it will raise
    # an exception if the ID doesn't exist.
    matching_events = Event.where(id: event_id)

    return unless matching_events.count == 1

    event = matching_events[0]

    self.fee_relationship = FeeRelationship.new(
      event_id: event.id,
      is_fee_payment: true,
    )

    self.display_name = "#{event.name} Bank Fee"
    self.save
  end

  def try_pair_emburse
    return unless potential_emburse?

    # emburse transfers will be negative on the account balance
    unpaired_matching_amount = EmburseTransfer
                               .unpaired.where(load_amount: -self.amount)
                               .order(accepted_at: :desc)

    return unless unpaired_matching_amount.count == 1

    emburse_transfer = unpaired_matching_amount[0]

    self.emburse_transfer = emburse_transfer

    self.fee_relationship = FeeRelationship.new(
      event_id: emburse_transfer.event.id,
      fee_applies: false
    )

    self.display_name = "Transfer from account to card balance"
    self.save
  end

  def try_pair_github
    return unless potential_github?

    potential_event_name = /(.*)GitHub Grant.*/.match(self.name)[1].strip
    matching_events = Event.where(name: potential_event_name)

    return unless matching_events.count == 1

    event = matching_events[0]

    self.fee_relationship = FeeRelationship.new(
      event_id: event.id,
      fee_applies: false
    )

    self.save
  end

  def try_pair_ach_transfer
    # This is largely modeled after try_pair_emburse
    return unless potential_ach_transfer?

    # ach transfers out will be negative on the account balance
    unpaired_matching_amount = AchTransfer
                               .approved
                               .where(amount: -self.amount)
                               .order(approved_at: :desc)
                               .in_transit

    return unless unpaired_matching_amount.count > 0

    matched_ach = unpaired_matching_amount[0]

    self.ach_transfer = matched_ach

    self.fee_relationship = FeeRelationship.new(
      event_id: matched_ach.event.id,
      fee_applies: false
    )

    self.display_name = "ACH direct deposit out to #{matched_ach.recipient_name}"
    self.save
  end

  def try_pair_check
    return unless potential_check?

    Check.in_transit.each do |check|
      next unless self.amount.abs == check.amount.abs

      self.check = check

      # if from a positive pay account, does not belong to any event
      if self.bank_account.is_positive_pay?
        self.is_event_related = false
      else
        self.fee_relationship = FeeRelationship.new(
          event_id: check.event.id,
          fee_applies: false
        )
      end

      self.display_name = "Check to #{check.lob_address.name} - #{check.memo}"
      self.save

      break
    end
  end

  def try_pair_disbursement
    return unless potential_disbursement?

    match = /HCB DISBURSE (\d*).*/.match(self.name)
    disbursement_id = match ? match[1].to_i : 0

    return if disbursement_id == 0

    # we don't use Event.find here because it will raise
    # an exception if the ID doesn't exist.
    matching_disbursements = Disbursement.where(id: disbursement_id)

    return unless matching_disbursements.count == 1

    disbursement = matching_disbursements[0]
    # if money coming in, it's for destination event. otherwise,
    # it's for source event
    event = self.amount > 0 ? disbursement.event : disbursement.source_event

    self.disbursement = disbursement

    self.fee_relationship = FeeRelationship.new(
      event_id: event.id,
      fee_applies: false
    )

    self.display_name = "#{disbursement.name} from #{disbursement.source_event.name}"
    self.save
  end

  def slug_text
    "#{date} #{name}"
  end

  def filter_for(text)
    name&.downcase&.include? text
  end

end
