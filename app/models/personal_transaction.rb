# frozen_string_literal: true

# == Schema Information
#
# Table name: personal_transactions
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  invoice_id     :bigint           not null
#  ledger_item_id :bigint           not null
#  reporter_id    :bigint           not null
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
  validate :ledger_item_is_linked_to_a_card_charge
  validate :ledger_item_is_a_qualifying_charge

  before_validation :send_invoice, on: :create, if: -> { invoice.nil? }

  after_create do
    # Calling this on either side syncs marked_no_or_lost_receipt_at onto both
    # hcb_code and ledger_item (Receiptable#sync_no_or_lost_receipt!), so that
    # part doesn't depend on which one we call here. What does depend on it:
    # CardLocking::ReceiptResolution.on_no_or_lost_receipt only materializes
    # card-locking state (and checks the cardholder's unlock) for whichever
    # object it's handed, gated on `is_a?(HcbCode)` — the sync's plain
    # `counterpart.update!` on the other side never re-triggers that. Calling
    # ledger_item.no_or_lost_receipt! would still mark hcb_code correctly, but
    # would skip clearing hcb_code's own receipt_due_at/receipt_resolved_at
    # and skip the unlock check — and since a marked charge no longer matches
    # HcbCode.card_locking_candidates, nothing else revisits it to fix that up
    # later. Confirmed by spying on CardLocking::ReceiptResolution: calling
    # this on ledger_item syncs hcb_code's column but passes the Ledger::Item,
    # never the HcbCode, into on_no_or_lost_receipt.
    hcb_code = ledger_item.hcb_code
    hcb_code.no_or_lost_receipt! if hcb_code.missing_receipt?
  end

  private

  def ledger_item_is_linked_to_a_card_charge
    return if ledger_item.nil?
    return if ledger_item.linked_object_type == "CardCharge"

    errors.delete(:invoice)
    errors.add(:base, "Invoices can only be generated for card charges.")
  end

  def ledger_item_is_a_qualifying_charge
    return if ledger_item.nil?
    return if ledger_item.amount_cents <= -100

    # Supersede the belongs_to :invoice presence error (invoice is never sent
    # for a non-qualifying charge) with the message that actually explains it.
    errors.delete(:invoice)
    errors.add(:base, "Invoices can only be generated for charges of $1.00 or more.")
  end

  # before_validation callbacks always run before validate-registered
  # validations, so this can't rely on the validate methods above having run
  # yet — it re-checks the same conditions itself before actually generating
  # an invoice. Otherwise a too-small charge, a non-card-charge, or a
  # duplicate submission would still send a real invoice before the record
  # gets rejected and thrown away.
  def send_invoice
    return if ledger_item.nil?
    return unless ledger_item.linked_object_type == "CardCharge"
    return unless ledger_item.amount_cents <= -100
    return if PersonalTransaction.exists?(ledger_item:)

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
