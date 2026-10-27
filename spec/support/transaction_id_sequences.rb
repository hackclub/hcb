# frozen_string_literal: true

# Factory-built canonical transactions and canonical pending transactions have
# no raw source, so TransactionGroupingEngine::Calculate::HcbCode gives both
# the fallback code "HCB-000-<id>". A CanonicalTransaction and a
# CanonicalPendingTransaction that land on the same id therefore share an HCB
# code, and the pending one reuses the settled one's ledger item
# (CanonicalPendingTransaction#calculated_ledger_item) — so mapping the pending
# transaction onto its event moves the settled transaction's money there too.
#
# Whether that happens depends on test order: ids come from Postgres
# sequences, which transactional rollbacks don't rewind. Keep the two id spaces
# apart so the fallback codes can never collide.
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT setval('canonical_pending_transactions_id_seq', GREATEST(last_value, 1000000000))
      FROM canonical_pending_transactions_id_seq
    SQL
  end
end
