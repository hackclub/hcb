class AddCommentCountsToLedgerItems < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_items, :comment_count, :integer, default: 0, null: false
    add_column :ledger_items, :not_admin_only_comment_count, :integer, default: 0, null: false
  end
end
