class EventDropTransactionEngineV2AtAndPendingTransactionEngineAt < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :transaction_engine_v2_at
      remove_column :events, :pending_transaction_engine_at
    end
  end
end
