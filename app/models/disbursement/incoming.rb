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

    delegate :may_mark_approved?, :may_mark_in_transit?, :may_mark_deposited?, :may_mark_errored?, :may_mark_rejected?, :may_mark_scheduled?, to: :disbursement

    def self.polymorphic_name
      "Disbursement::Incoming"
    end

    def hcb_code
      incoming_hcb_code
    end

    def counterparty
      disbursement.outgoing_disbursement
    end

    alias_method :event, :destination_event
    alias_method :counterparty_event, :source_event
    alias_method :subledger, :destination_subledger
    alias_method :counterparty_subledger, :source_subledger
    alias_method :transaction_category, :destination_transaction_category

    # These need to be updated later to not use HCB code
    def canonical_transactions
      @canonical_transactions ||= CanonicalTransaction.where(hcb_code: incoming_hcb_code)
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= ::CanonicalPendingTransaction.where(hcb_code: incoming_hcb_code)
    end

  end

end
