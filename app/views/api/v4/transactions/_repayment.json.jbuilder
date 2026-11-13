# frozen_string_literal: true

# locals: (json:, ledger_item:, repaid_by:, repays:)

# The other side of a repayment can be in an organization the viewer can't
# see (a transfer from elsewhere), so its id is only shown when visible.
side = lambda do |items|
  json.array! items do |item|
    visible = item.hcb_code.present? && policy(item.hcb_code).show?
    json.id(visible ? item.hcb_code.public_id : nil)
    json.transfer item.linked_object_type.in?(["Disbursement::Outgoing", "Disbursement::Incoming"])
  end
end

json.repaid_by { side.call(repaid_by) }
json.repays { side.call(repays) }
json.can_unmark ledger_item.marked_repayment.present? && policy(ledger_item).unmark_repayment?
