# frozen_string_literal: true

module Admin
  class DetectLinkedObjectAnomaliesJob < ApplicationJob
    queue_as :low

    def perform
      anomalous_items = []
      Ledger::Item.where.not(linked_object_type: nil).find_each do |item|
        if item.hcb_code.present? && item.hcb_code.linked_object != item.linked_object
          anomalous_items << {
            id: item.id,
            hashid: item.hashid,
            memo: item.memo,
            hcb_code_lo_type: item.hcb_code.linked_object.class.name,
            hcb_code_lo_id: item.hcb_code.linked_object&.id,
            ledger_item_lo_type: item.linked_object_type,
            ledger_item_lo_id: item.linked_object_id
          }
          puts "Found anomaly on Ledger::Item (#{item.hashid})"
        end
      end

      Rails.cache.write("linked_object_anomalies", anomalous_items)

      AdminMailer.linked_object_anomalies(anomalous_items:).deliver_now
    end

  end
end
