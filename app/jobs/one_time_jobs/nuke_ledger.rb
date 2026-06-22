# frozen_string_literal: true

module OneTimeJobs
  class NukeLedger < ApplicationJob
    def perform
      delete_ledger_mappings
      clear_canonical_transaction_references
      delete_ledger_items
      delete_ledgers
      clear_papertrail_versions
    end

    def delete_ledger_mappings
      count = Ledger::Mapping.count
      puts "Deleting #{count} Ledger::Mapping records"
      Ledger::Mapping.delete_all
      puts "Deleted all Ledger::Mapping records"
    end

    def clear_canonical_transaction_references
      pending_count = CanonicalPendingTransaction.where.not(ledger_item_id: nil).count
      transaction_count = CanonicalTransaction.where.not(ledger_item_id: nil).count
      puts "Clearing ledger_item_id on #{pending_count} CanonicalPendingTransactions"
      CanonicalPendingTransaction.update_all(ledger_item_id: nil)
      puts "Clearing ledger_item_id on #{transaction_count} CanonicalTransactions"
      CanonicalTransaction.update_all(ledger_item_id: nil)
    end

    def delete_ledger_items
      count = Ledger::Item.count
      puts "Deleting #{count} Ledger::Item records"
      Ledger::Item.delete_all
      puts "Deleted all Ledger::Item records"
    end

    def delete_ledgers
      count = Ledger.count
      puts "Deleting #{count} Ledger records"
      Ledger.delete_all
      puts "Deleted all Ledger records"
    end

    def clear_papertrail_versions
      ledger_versions = PaperTrail::Version.where(item_type: ["Ledger", "Ledger::Item", "Ledger::Mapping"]).count
      puts "Deleting #{ledger_versions} PaperTrail versions for Ledger models"
      PaperTrail::Version.where(item_type: ["Ledger", "Ledger::Item", "Ledger::Mapping"]).delete_all

      hcb_code_versions = PaperTrail::Version.where(item_type: "HcbCode")
                                             .where("object_changes::text LIKE ?", "%ledger_item_id%")
                                             .count
      puts "Deleting #{hcb_code_versions} PaperTrail versions for HcbCode with ledger_item_id changes"
      PaperTrail::Version.where(item_type: "HcbCode")
                         .where("object_changes::text LIKE ?", "%ledger_item_id%")
                         .delete_all
    end
  end
end
