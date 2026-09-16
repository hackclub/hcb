# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_items_tags
#
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ledger_item_id :bigint           not null, primary key
#  tag_id         :bigint           not null, primary key
#
# Indexes
#
#  index_ledger_items_tags_on_tag_id  (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#  fk_rails_...  (tag_id => tags.id)
#
class Ledger
  class Item < ApplicationRecord
    class Tag < ApplicationRecord
      self.table_name = "ledger_items_tags"
      self.primary_key = [:ledger_item_id, :tag_id]

      belongs_to :ledger_item, class_name: "Ledger::Item"
      belongs_to :tag
      has_one :event, through: :tag

    end

  end

end
