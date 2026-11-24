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
    url_helpers.transaction_url(self)
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
  # They are used when rendering Transaction#edit
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

  def potential_ach_transfer?
    self.name.include?("BUSBILLPAY")
  end

  def potential_disbursement?
    self.name.start_with?("HCB DISBURSE")
  end

  def receipt_required?
    false
  end

  private

  def slug_text
    "#{date} #{name}"
  end

end
