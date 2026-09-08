# frozen_string_literal: true

# == Schema Information
#
# Table name: card_charge_raw_stripe_transactions
#
#  id                        :bigint           not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  card_charge_id            :bigint           not null
#  raw_stripe_transaction_id :bigint           not null
#
# Indexes
#
#  index_card_charge_raw_stripe_transactions_on_card_charge_id  (card_charge_id)
#  index_card_charge_rsts_on_raw_stripe_transaction_id          (raw_stripe_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (card_charge_id => card_charges.id) ON DELETE => cascade
#  fk_rails_...  (raw_stripe_transaction_id => raw_stripe_transactions.id) ON DELETE => cascade
#
class CardChargeRawStripeTransaction < ApplicationRecord
  belongs_to :card_charge
  belongs_to :raw_stripe_transaction

  validate :stripe_authorization_id_matches_card_charge, on: :create

  private

  def stripe_authorization_id_matches_card_charge
    return if card_charge.nil? || raw_stripe_transaction.nil?

    authorization_id = raw_stripe_transaction.stripe_authorization_id

    if authorization_id.nil?
      # A force capture has no authorization, so it can only ever be the
      # charge's sole transaction.
      if card_charge.raw_pending_stripe_transaction.present? || sibling_raw_stripe_transactions.any?
        errors.add(:raw_stripe_transaction, "has no authorization and can not join a charge with other transactions")
      end
    else
      charge_authorization_id = card_charge.raw_pending_stripe_transaction&.stripe_transaction_id ||
                                sibling_raw_stripe_transactions.filter_map(&:stripe_authorization_id).first

      if charge_authorization_id.present? && charge_authorization_id != authorization_id
        errors.add(:raw_stripe_transaction, "belongs to authorization #{authorization_id}, but the charge is for #{charge_authorization_id}")
      end
    end
  end

  def sibling_raw_stripe_transactions
    @sibling_raw_stripe_transactions ||= card_charge.raw_stripe_transactions.where.not(id: raw_stripe_transaction.id).to_a
  end

end
