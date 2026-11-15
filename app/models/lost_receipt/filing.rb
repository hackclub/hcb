# frozen_string_literal: true

# == Schema Information
#
# Table name: lost_receipt_filings
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint
#  receipt_id :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_lost_receipt_filings_on_event_id    (event_id)
#  index_lost_receipt_filings_on_receipt_id  (receipt_id) UNIQUE
#  index_lost_receipt_filings_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (receipt_id => receipts.id)
#  fk_rails_...  (user_id => users.id)
#
module LostReceipt
  # One row per lost receipt statement on file, so lost receipts can be counted
  # per organization and per cardholder. Deleted along with the statement.
  class Filing < ApplicationRecord
    belongs_to :receipt
    belongs_to :event, optional: true
    belongs_to :user, optional: true

  end
end
