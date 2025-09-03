# frozen_string_literal: true

# == Schema Information
#
# Table name: hcb_code_personal_transactions
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  hcb_code_id :bigint
#  invoice_id  :bigint
#  reporter_id :bigint
#
# Indexes
#
#  index_hcb_code_personal_transactions_on_hcb_code_id  (hcb_code_id) UNIQUE
#  index_hcb_code_personal_transactions_on_invoice_id   (invoice_id)
#  index_hcb_code_personal_transactions_on_reporter_id  (reporter_id)
#
# Foreign Keys
#
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (reporter_id => users.id)
#
class HcbCode
  class PersonalTransaction < ApplicationRecord
    belongs_to :hcb_code
    validates :hcb_code, uniqueness: true, presence: true
    belongs_to :invoice
    belongs_to :reporter, class_name: "User"

    before_validation :send_invoice, on: :create, if: -> { invoice.nil? }

    after_create do
      hcb_code.no_or_lost_receipt! if hcb_code.missing_receipt?
    end

    private

    def send_invoice
      event = hcb_code.event
      spender = hcb_code.stripe_cardholder&.user || reporter
      self.invoice = ::InvoiceService::Create.new(
        event_id: event.id,
        due_date: 1.month.from_now,
        item_description: "Reimbursing personal transaction: #{hcb_code.memo}",
        item_amount: hcb_code.amount.abs,
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

end
