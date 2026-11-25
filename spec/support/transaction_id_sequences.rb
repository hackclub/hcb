# frozen_string_literal: true

# Keep canonical transaction and canonical pending transaction ids apart.
#
# A factory-built transaction has no raw source, so
# TransactionGroupingEngine::Calculate::HcbCode gives it the catch-all code
# "HCB-000-<id>". CanonicalTransaction and CanonicalPendingTransaction use
# separate id sequences, so a CT and an unrelated CPT that happen to share an id
# also share an HCB code, and the CT joins the CPT's ledger item. Whether two
# ids line up depends on how many rows earlier specs in the process created,
# which made specs fail (e.g. "has calculated a different ledger item from its
# local_hcb_code") only for some seeds and shard splits.
#
# Starting the CPT sequence far past anything the suite creates means a bare
# factory CT and CPT never share an id.
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      ALTER SEQUENCE canonical_pending_transactions_id_seq RESTART WITH 1000000000
    SQL
  end
end
