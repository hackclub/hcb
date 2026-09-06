# frozen_string_literal: true

class Ledger
  class AssertAllRequirementsJob < ApplicationJob
    queue_as :low

    def perform
      Ledger::AssertCtsSyncedWithHcbCodeJob.perform_later
      Ledger::AssertCptsSyncedWithHcbCodeJob.perform_later
      Ledger::AssertLedgerSyncedWithHcbCodeJob.perform_later
      Ledger::AssertNoOrphanedCtsJob.perform_later
      Ledger::AssertNoOrphanedCptsJob.perform_later
      Ledger::AssertCemsMatchLedgerMappingJob.perform_later
      Ledger::AssertCpemsMatchLedgerMappingJob.perform_later
      Ledger::AssertCorrectLedgerBalancesJob.perform_later
    end

  end

end
