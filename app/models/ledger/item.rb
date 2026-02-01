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

    include Commentable
    include Receiptable

    has_many :ledger_mappings, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_mapping, -> { where(on_primary_ledger: true) }, class_name: "Ledger::Mapping", foreign_key: :ledger_item_id, inverse_of: :ledger_item
    has_one :primary_ledger, through: :primary_mapping, source: :ledger, class_name: "::Ledger"
    has_many :all_ledgers, through: :ledger_mappings, source: :ledger, class_name: "::Ledger"

    validates_presence_of :amount_cents, :memo, :date

    monetize :amount_cents

    def receipt_required?
      false
    end

  end

end
