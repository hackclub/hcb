# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_revenues
#
#  id           :bigint           not null, primary key
#  aasm_state   :string           not null
#  amount_cents :integer
#  end          :date
#  start        :date
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class FeeRevenue < ApplicationRecord
  include AASM
  include HasBookTransfer

  include Hashid::Rails
  hashid_config salt: ""

  include PublicIdentifiable
  set_public_id_prefix :frv

  has_one :ledger_item, as: :linked_object
  has_one :raw_pending_fee_revenue_transaction
  has_many :bank_fees

  include HasHcbCode
  has_hcb_code ::TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE, eager_create: true

  after_create_commit :create_canonical_pending_transaction

  aasm do
    state :pending, initial: true
    state :in_transit
    state :settled

    event :mark_in_transit do
      transitions from: :pending, to: :in_transit
    end

    event :mark_settled do
      transitions from: :in_transit, to: :settled
    end
  end

  def canonical_transaction
    @canonical_transaction ||= CanonicalTransaction.find_by(hcb_code:)
  end

  def event
    Event.find(::EventMappingEngine::EventIds::HACK_CLUB_BANK)
  end

  private

  def create_canonical_pending_transaction
    rpfrt = create_raw_pending_fee_revenue_transaction!(
      date_posted: self.end,
      amount_cents:
    )

    canonical_pending_transaction = CanonicalPendingTransaction.create!(
      date: rpfrt.date,
      amount_cents: rpfrt.amount_cents,
      raw_pending_fee_revenue_transaction: rpfrt
    )

    TransactionCategoryService
      .new(model: canonical_pending_transaction)
      .set!(
        slug: "hcb-revenue",
        assignment_strategy: :automatic
      )

    CanonicalPendingEventMapping.create!(
      event:,
      canonical_pending_transaction:
    )
  end

end
