# frozen_string_literal: true

# == Schema Information
#
# Table name: subledgers
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_subledgers_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Subledger < ApplicationRecord
  belongs_to :event

  has_one :card_grant

  has_many :hcb_codes

  has_many :canonical_event_mappings
  has_many :canonical_transactions, through: :canonical_event_mappings

  has_many :canonical_pending_event_mappings
  has_many :canonical_pending_transactions, through: :canonical_pending_event_mappings

  monetize :balance_cents

  def balance_cents
    canonical_transactions.sum(:amount_cents) +
      canonical_pending_transactions.outgoing.unsettled.sum(:amount_cents) +
      canonical_pending_transactions.incoming_disbursement.unsettled.fronted.sum(:amount_cents)
  end

end
