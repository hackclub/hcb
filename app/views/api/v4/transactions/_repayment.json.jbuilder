# frozen_string_literal: true

# locals: (json:, repaid_by:, repays:)

# The other side of a repayment can be in an organization the viewer can't
# see (a transfer from elsewhere), so its id is only shown when visible.
side = lambda do |items|
  json.array! items do |item|
    visible = item.hcb_code.present? && policy(item).show?
    json.id(visible ? item.hcb_code.public_id : nil)
    json.transfer item.linked_object_type.in?(["Disbursement::Outgoing", "Disbursement::Incoming"])
  end
end

json.repaid_by { side.call(repaid_by) }
json.repays { side.call(repays) }
