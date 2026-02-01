# frozen_string_literal: true

# Alias the ledgerjournal gem's top-level Ledger module so it doesn't
# conflict with our own Ledger model.
LedgerJournal = Ledger
LedgerJournal::Transaction::Ledger = Ledger
LedgerJournal::Ledger = Ledger
Object.send(:remove_const, :Ledger)
