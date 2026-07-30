# frozen_string_literal: true

module Maintenance
  # Backfills `ledger_items.special_appearance` from the memo — the only place the
  # appearance was ever recorded before the column existed, since it was computed
  # on read from the disbursement's source fund.
  #
  # This is a one-time bridge: once an item has the column set, `Ledger::Item`
  # regenerates the same memo *from* the appearance on every refresh, so the two
  # can't drift. New items get the column from the qualifiers instead.
  class BackfillLedgerItemSpecialAppearancesTask < MaintenanceTasks::Task
    MEMOS = Ledger::Item::SpecialAppearance::ALL.index_by(&:memo).freeze

    def collection
      # `custom_memo: nil` guards against a user who happened to rename a
      # transaction to exactly one of these strings: their item would otherwise be
      # given an appearance it never had.
      Ledger::Item.where(special_appearance: nil, custom_memo: nil, memo: MEMOS.keys)
    end

    def process(item)
      appearance = MEMOS[item.memo]
      return unless appearance

      # update_column, not update!: this is cosmetic, so it's not worth a
      # paper_trail version or a bumped updated_at on every affected item.
      item.update_column(:special_appearance, appearance.key)
    end

  end
end
