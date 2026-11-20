# frozen_string_literal: true

# == Schema Information
#
# Table name: suggested_pairings
#
#  id             :bigint           not null, primary key
#  aasm_state     :string           not null
#  accepted_at    :datetime
#  distance       :float
#  ignored_at     :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hcb_code_id    :bigint           not null
#  ledger_item_id :bigint
#  receipt_id     :bigint           not null
#
# Indexes
#
#  index_suggested_pairings_on_hcb_code_id                    (hcb_code_id)
#  index_suggested_pairings_on_ledger_item_id                 (ledger_item_id)
#  index_suggested_pairings_on_receipt_id                     (receipt_id)
#  index_suggested_pairings_on_receipt_id_and_hcb_code_id     (receipt_id,hcb_code_id) UNIQUE
#  index_suggested_pairings_on_receipt_id_and_ledger_item_id  (receipt_id,ledger_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ledger_item_id => ledger_items.id) ON DELETE => cascade
#
class SuggestedPairing < ApplicationRecord
  belongs_to :receipt
  # The HCB code is on its way out (https://github.com/hackclub/hcb/issues/15698):
  # the pairing is read and accepted through its ledger item. Rows written
  # before the ledger item was backfilled for a code without one have no
  # ledger item, and are never suggested.
  belongs_to :hcb_code
  belongs_to :ledger_item, class_name: "Ledger::Item", optional: true

  include AASM

  aasm timestamps: true do
    state :unreviewed, initial: true # Suggestion is ready and waiting to be reviewed
    state :ignored                   # User has ignored the suggestion
    state :accepted                  # User has accepted the suggestion
    state :reversed                  # User has reversed the suggestion (auto-applied via email)

    event :mark_ignored do
      transitions from: :unreviewed, to: :ignored
    end

    event :mark_accepted do
      before do
        receipt.update!(receiptable: ledger_item)
      end

      transitions from: :unreviewed, to: :accepted
    end

    event :mark_reversed do
      before do
        receipt.update!(receiptable: nil)
      end

      transitions from: :accepted, to: :reversed
    end
  end

  def ignored?
    !!ignored_at
  end

  def accepted?
    !!accepted_at
  end

end
