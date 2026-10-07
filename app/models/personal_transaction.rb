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
  # Rails-level presence is deliberately relaxed here (the DB still enforces
  # NOT NULL on invoice_id) so that validation can pass on ledger_item's own
  # merits before invoice exists — see send_invoice below.
  belongs_to :invoice, optional: true
  belongs_to :reporter, class_name: "User"

  validates :ledger_item, uniqueness: true, presence: true
  validate :ledger_item_is_linked_to_a_card_charge
  validate :ledger_item_is_a_qualifying_charge

  # before_create only runs once validation has already passed, so by the
  # time this fires, ledger_item is already confirmed to be a qualifying,
  # not-yet-invoiced card charge — send_invoice can rely on that instead of
  # re-checking it.
  before_create :send_invoice, if: -> { invoice.nil? }

  after_create do
    ledger_item.no_or_lost_receipt! if ledger_item.missing_receipt?
  end

  private

  def ledger_item_is_linked_to_a_card_charge
    return if ledger_item.nil?
    return if ledger_item.linked_object_type == "CardCharge"

    errors.add(:base, "Invoices can only be generated for card charges.")
  end

  def ledger_item_is_a_qualifying_charge
    return if ledger_item.nil?
    return if ledger_item.amount_cents <= -100

    errors.add(:base, "Invoices can only be generated for charges of $1.00 or more.")
  end

  def send_invoice
    card_charge = ledger_item.linked_object
    event = ledger_item.primary_ledger&.event || ledger_item.primary_ledger&.card_grant&.event
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
