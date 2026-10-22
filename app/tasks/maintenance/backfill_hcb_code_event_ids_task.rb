# frozen_string_literal: true

module Maintenance
  class BackfillHcbCodeEventIdsTask < MaintenanceTasks::Task
    class AnomalyError < StandardError; end

    def collection
      HcbCode.all
    end

    def process(hcb_code)
      previous_event_id = hcb_code.event_id
      previous_subledger_id = hcb_code.subledger_id

      hcb_code.send :write_event_and_subledger_id

      hcb_code.reload

      if hcb_code.event_id != previous_event_id || hcb_code.subledger_id != previous_subledger_id
        Rails.error.report AnomalyError.new("HcbCode #{hcb_code.id} had its event_id or subledger_id changed from #{previous_event_id}/#{previous_subledger_id} to #{hcb_code.event_id}/#{hcb_code.subledger_id}")
      end
    end

  end
end
