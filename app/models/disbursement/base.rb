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
  class Base < ApplicationRecord
    self.table_name = "disbursements"

    belongs_to :disbursement, class_name: "::Disbursement", inverse_of: :base_disbursement, foreign_key: :id

    def canonical_transactions
      @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= CanonicalPendingTransaction.where(hcb_code:)
    end

    def pending_expired?
      local_hcb_code.has_pending_expired?
    end

    def transaction_memo
      "HCB-#{local_hcb_code.short_code}"
    end

    def local_hcb_code
      @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
    end

    def self_label
      format_party_label(subledger, event)
    end

    def counterparty_label
      format_party_label(counterparty_subledger, counterparty_event)
    end

    private

    # A card grant is a disbursement between the same event, so we want to use the grant recipient
    # to differentiate transaction parties
    def format_party_label(subledger, event)
      card_grant = subledger&.card_grant
      card_grant ? "Grant recipient #{card_grant.user.name}" : event.name
    end

  end

end
