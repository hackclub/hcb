# frozen_string_literal: true

# == Schema Information
#
# Table name: personal_transactions
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  invoice_id     :bigint
#  ledger_item_id :bigint
#  reporter_id    :bigint
#
# Indexes
#
#  index_personal_transactions_on_invoice_id      (invoice_id)
#  index_personal_transactions_on_ledger_item_id  (ledger_item_id) UNIQUE
#  index_personal_transactions_on_reporter_id     (reporter_id)
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#  fk_rails_...  (reporter_id => users.id)
#
class PersonalTransaction < ApplicationRecord
  belongs_to :ledger_item, class_name: "Ledger::Item", inverse_of: :personal_transaction
  belongs_to :invoice
  belongs_to :reporter, class_name: "User"

  validates :ledger_item, uniqueness: true, presence: true
  # Declared after the belongs_to's so its implicit presence validator (on
  # :invoice) has already run and can be superseded below.
  validate :ledger_item_is_a_qualifying_charge

  # before_validation callbacks always run before validate-registered
  # validations, so gate this on the same conditions ledger_item_is_a_qualifying_charge
  # and the ledger_item uniqueness validation check — otherwise an
  # already-doomed-to-be-invalid record would still send a real invoice
  # before getting rejected and thrown away.
  before_validation :send_invoice, on: :create, if: -> { invoice.nil? && ledger_item_ready_for_invoice? }

  after_create do
    # This stays keyed off hcb_code (rather than ledger_item.no_or_lost_receipt!)
    # because CardLocking::ReceiptResolution.on_no_or_lost_receipt only acts on
    # HcbCode instances; calling it on the ledger item directly would silently
    # skip the cardholder's unlock recompute.
    hcb_code = ledger_item.hcb_code
    hcb_code.no_or_lost_receipt! if hcb_code.missing_receipt?
  end

  private

  def ledger_item_is_a_qualifying_charge
    return if ledger_item.nil?
    return if ledger_item.amount_cents <= -100

    # Supersede the belongs_to :invoice presence error (invoice is never sent
    # for a non-qualifying charge) with the message that actually explains it.
    errors.delete(:invoice)
    errors.add(:base, "Invoices can only be generated for charges of $1.00 or more.")
  end

  def ledger_item_ready_for_invoice?
    ledger_item.present? && ledger_item.amount_cents <= -100 && !PersonalTransaction.exists?(ledger_item:)
  end

  def send_invoice
    card_charge = ledger_item.linked_object
    event = ledger_item.primary_ledger&.event
    spender = card_charge.stripe_cardholder&.user || reporter
    self.invoice = ::InvoiceService::Create.new(
      event_id: event.id,
      due_date: 1.month.from_now,
      item_description: "Reimbursing personal transaction: #{ledger_item.memo}",
      item_amount: ledger_item.amount.abs,
      current_user: reporter,
      sponsor_id: nil,
      sponsor_name: spender.name,
      sponsor_email: spender.email,
      sponsor_address_line1: spender.stripe_cardholder.stripe_billing_address_line1,
      sponsor_address_line2: spender.stripe_cardholder.stripe_billing_address_line2,
      sponsor_address_city: spender.stripe_cardholder.stripe_billing_address_city,
      sponsor_address_state: spender.stripe_cardholder.stripe_billing_address_state,
      sponsor_address_postal_code: spender.stripe_cardholder.stripe_billing_address_postal_code,
      sponsor_address_country: spender.stripe_cardholder.stripe_billing_address_country
    ).run
  end

end
