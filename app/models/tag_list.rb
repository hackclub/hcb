# frozen_string_literal: true

# == Schema Information
#
# Table name: tag_lists
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# The tags a ledger offers. Tags hang off a list rather than an event because
# not every ledger is owned by an event (https://github.com/hackclub/hcb/issues/15708).
# An event's ledger and the ledgers of its card grants share one list, so a
# grant's charges can be tagged alongside the event's transactions.
class TagList < ApplicationRecord
  has_many :tags, dependent: :destroy
  has_many :ledgers, inverse_of: :tag_list

  # The event whose ledger this list belongs to. Card grant ledgers share the
  # list but don't own it.
  has_one :event_ledger, -> { where.not(event_id: nil) }, class_name: "Ledger", inverse_of: :tag_list
  has_one :event, through: :event_ledger

end
