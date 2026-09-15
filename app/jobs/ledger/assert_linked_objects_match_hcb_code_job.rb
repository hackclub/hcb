# frozen_string_literal: true

class Ledger
  # A Ledger::Item stores its linked object in a polymorphic column, assigned
  # once from the first transaction to map into it. Its HcbCode derives the same
  # object from the HCB code string. The two must agree.
  class AssertLinkedObjectsMatchHcbCodeJob < AssertRequirementJob
    def perform
      @ledger_items = Ledger::Item.where.not(linked_object_type: nil).includes(:hcb_code, :linked_object)

      @ledger_items.find_each do |item|
        safely do
          hcb_code = item.hcb_code
          next if hcb_code.nil?

          linked_object = hcb_code.linked_object
          next if linked_object == item.linked_object

          report_anomaly "Ledger::Item #{item.hashid} linked_object (#{item.linked_object_type} #{item.linked_object_id}) does not match HcbCode #{hcb_code.hashid} linked_object (#{linked_object.class.name} #{linked_object&.id})"
        end
      end
    end

  end

end
