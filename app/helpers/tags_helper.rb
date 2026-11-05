# frozen_string_literal: true

module TagsHelper
  def tag_dom_id(ledger_item, tag, suffix = "")
    "ledger_item_#{ledger_item.hashid}_tag_#{tag.id}#{suffix}"
  end

  def tag_dom_class(*args)
    ".#{tag_dom_id(*args)}"
  end
end
