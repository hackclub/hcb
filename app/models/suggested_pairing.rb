# frozen_string_literal: true

# == Schema Information
#
# Table name: suggested_pairings
#
#  id          :bigint           not null, primary key
#  aasm_state  :string
#  accepted_at :datetime
#  distance    :float
#  ignored_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  hcb_code_id :bigint           not null
#  receipt_id  :bigint           not null
#
# Indexes
#
#  index_suggested_pairings_on_hcb_code_id                 (hcb_code_id)
#  index_suggested_pairings_on_receipt_id                  (receipt_id)
#  index_suggested_pairings_on_receipt_id_and_hcb_code_id  (receipt_id,hcb_code_id) UNIQUE
#
class SuggestedPairing < ApplicationRecord
  belongs_to :receipt
  belongs_to :hcb_code

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
        receipt.update!(receiptable: hcb_code)
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
