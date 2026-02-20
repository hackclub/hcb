# frozen_string_literal: true

# == Schema Information
#
# Table name: invoice_payouts
#
#  id                                    :bigint           not null, primary key
#  amount                                :bigint
#  arrival_date                          :datetime
#  automatic                             :boolean
#  currency                              :text
#  description                           :text
#  failure_code                          :text
#  failure_message                       :text
#  method                                :text
#  source_type                           :text
#  statement_descriptor                  :text
#  status                                :text
#  stripe_created_at                     :datetime
#  type                                  :text
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  failure_stripe_balance_transaction_id :text
#  stripe_balance_transaction_id         :text
#  stripe_destination_id                 :text
#  stripe_payout_id                      :text
#
# Indexes
#
#  index_invoice_payouts_on_failure_stripe_balance_transaction_id  (failure_stripe_balance_transaction_id) UNIQUE
#  index_invoice_payouts_on_stripe_balance_transaction_id          (stripe_balance_transaction_id) UNIQUE
#  index_invoice_payouts_on_stripe_payout_id                       (stripe_payout_id) UNIQUE
#
class InvoicePayout < ApplicationRecord
  has_paper_trail

  include StripePayoutable

  # find invoice payouts that don't yet have an associated transaction
  scope :lacking_transaction, -> { includes(:t_transaction).where(transactions: { invoice_payout_id: nil }) }
  scope :invoice_hcb_code, -> { where("statement_descriptor ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}%'") }

  # although it normally doesn't make sense for a paynot not to be linked to an invoice,
  # Stripe's schema makes this possible, and when that happens, requiring invoice<>payout breaks bank
  has_one :invoice, inverse_of: :payout, foreign_key: :payout_id
  has_one :event, through: :invoice
  has_one :t_transaction, class_name: "Transaction"

  delegate :hcb_code, :local_hcb_code, to: :invoice

  after_initialize :default_values

  # Description when displaying a payout in a form dropdown for associating
  # transactions.
  include ApplicationHelper # for render_money helper
  def dropdown_description
    "##{self.id} (#{render_money self.amount}, #{self.invoice&.sponsor&.event&.name}, inv ##{self.invoice&.id} for #{self.invoice&.sponsor&.name})"
  end

  private

  def default_values
    return unless invoice

    self.statement_descriptor ||= "HCB-#{local_hcb_code.short_code}"
  end

  def stripe_payout_params
    {
      amount: self.amount,
      currency: "usd",
      description: self.description,
      destination: self.stripe_destination_id,
      method: self.method,
      source_type: self.source_type,
      statement_descriptor: self.statement_descriptor
    }
  end

end
