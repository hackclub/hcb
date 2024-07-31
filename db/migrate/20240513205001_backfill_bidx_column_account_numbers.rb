class BackfillBidxColumnAccountNumbers < ActiveRecord::Migration[7.1]
  def change
    BlindIndex.backfill(Column::AccountNumber)
  end
end
