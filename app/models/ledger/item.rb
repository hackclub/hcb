# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_items
#
#  id                           :bigint           not null, primary key
#  amount_cents                 :integer          not null
#  date                         :datetime         not null
#  marked_no_or_lost_receipt_at :datetime
#  memo                         :text             not null
#  short_code                   :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
class Ledger
  class Item < ApplicationRecord
    self.table_name = "ledger_items"

    include Hashid::Rails
    hashid_config salt: Credentials.fetch(:HASHID_SALT)
    has_paper_trail

    validates_presence_of :amount_cents, :memo, :date

  end

end
