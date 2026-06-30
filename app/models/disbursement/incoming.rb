# frozen_string_literal: true

# == Schema Information
#
# Table name: disbursements
#
#  id                                  :bigint           not null, primary key
#  aasm_state                          :string           not null
#  amount                              :integer
#  deposited_at                        :datetime
#  errored_at                          :datetime
#  in_transit_at                       :datetime
#  name                                :string
#  pending_at                          :datetime
#  rejected_at                         :datetime
#  scheduled_on                        :date
#  should_charge_fee                   :boolean          default(FALSE)
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  destination_subledger_id            :bigint
#  destination_transaction_category_id :bigint
#  event_id                            :bigint
#  fulfilled_by_id                     :bigint
#  requested_by_id                     :bigint
#  source_event_id                     :bigint
#  source_subledger_id                 :bigint
#  source_transaction_category_id      :bigint
#
# Indexes
#
#  index_disbursements_on_destination_subledger_id             (destination_subledger_id)
#  index_disbursements_on_destination_transaction_category_id  (destination_transaction_category_id)
#  index_disbursements_on_event_id                             (event_id)
#  index_disbursements_on_fulfilled_by_id                      (fulfilled_by_id)
#  index_disbursements_on_requested_by_id                      (requested_by_id)
#  index_disbursements_on_source_event_id                      (source_event_id)
#  index_disbursements_on_source_subledger_id                  (source_subledger_id)
#  index_disbursements_on_source_transaction_category_id       (source_transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (destination_transaction_category_id => transaction_categories.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (fulfilled_by_id => users.id)
#  fk_rails_...  (requested_by_id => users.id)
#  fk_rails_...  (source_event_id => events.id)
#  fk_rails_...  (source_transaction_category_id => transaction_categories.id)
#
class Disbursement
  class Incoming < Disbursement::Base
    include Disbursement::Shared

    belongs_to :disbursement, class_name: "::Disbursement", inverse_of: :incoming_disbursement, foreign_key: :id

    def self.polymorphic_name
      "Disbursement::Incoming"
    end

    def hcb_code
      disbursement.incoming_hcb_code
    end

    def event
      disbursement.destination_event
    end

    def counterparty_event
      disbursement.source_event
    end

    def subledger
      disbursement.destination_subledger
    end

    def counterparty_subledger
      disbursement.source_subledger
    end

    def counterparty
      disbursement.outgoing_disbursement
    end

    def transaction_category
      disbursement.destination_transaction_category
    end

    def canonical_transactions
      @canonical_transactions ||= disbursement.canonical_transactions.where("amount_cents > 0")
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= disbursement.canonical_pending_transactions.where("amount_cents > 0")
    end

    def pending_expired?
      canonical_pending_transactions.pending_expired.any?
    end

  end

end
