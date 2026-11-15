# frozen_string_literal: true

# Sets tin_verified for the forms that already counted as verified before the
# column existed: those TaxBandits TIN-matched, and Tax1099 imports. Run as a
# migration rather than a maintenance task so that no deploy ever sees the
# column without its backfill: until it runs, every one of those payees would be
# unpayable. tax_forms is small, but it's still batched so no single statement
# holds row locks for long.
class BackfillTinVerifiedOnTaxForms < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class TaxForm < ActiveRecord::Base
    self.table_name = "tax_forms"

  end

  def up
    TaxForm.where(tin_verified: false)
           .where("taxbandits_tin_matching_status = 'success' OR source = 'tax1099'")
           .in_batches(of: 1_000) { |batch| batch.update_all(tin_verified: true) }
  end

  def down
    # Nothing to undo: the column's own migration removes it.
  end

end
