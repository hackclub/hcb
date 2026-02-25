# frozen_string_literal: true

# == Schema Information
#
# Table name: donation_payouts
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
#  index_donation_payouts_on_failure_stripe_balance_transaction_id  (failure_stripe_balance_transaction_id) UNIQUE
#  index_donation_payouts_on_stripe_balance_transaction_id          (stripe_balance_transaction_id) UNIQUE
#  index_donation_payouts_on_stripe_payout_id                       (stripe_payout_id) UNIQUE
#
class DonationPayout < ApplicationRecord
  has_paper_trail
  include StripePayoutable
  # find donation payouts that don't yet have an associated transaction
  scope :lacking_transaction, -> { includes(:t_transaction).where(transactions: { donation_payout_id: nil }) }
  scope :in_transit, -> { where(status: "in_transit") }
  scope :paid, -> { where(status: "paid") }
  scope :donation_hcb_code, -> { where("statement_descriptor ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE}%'") }

  # although it normally doesn't make sense for a paynot not to be linked to an donation,
  # Stripe's schema makes this possible, and when that happens, requiring donation<>payout breaks bank
  has_one :donation, inverse_of: :payout, foreign_key: :payout_id
  has_one :event, through: :donation
  has_one :t_transaction, class_name: "Transaction"

  delegate :hcb_code, :local_hcb_code, to: :donation

  validates_length_of :statement_descriptor, maximum: 22
  validates_uniqueness_of :statement_descriptor

  after_initialize :default_values

  # Description when displaying a payout in a form dropdown for associating
  # transactions.
  include ApplicationHelper # for render_money helper
  def dropdown_description
    "##{self.id} | #{render_money self.amount} (#{self.donation.event.name}, #{self.donation.name(show_anonymous: true)})"
  end

  private

  def default_values
    return unless donation

    self.statement_descriptor ||= "HCB-#{local_hcb_code.short_code}"
  end

  def stripe_payout_params
    {
      amount: self.donation.payout_creation_balance_net + self.donation.payout_creation_balance_stripe_fee,
      currency: "usd",
      description: self.description,
      destination: self.stripe_destination_id,
      method: self.method,
      source_type: self.source_type,
      statement_descriptor: self.statement_descriptor
    }
  end

end
