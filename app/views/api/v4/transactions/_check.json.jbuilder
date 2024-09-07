json.recipient_name check.recipient_name
json.memo check.local_hcb_code.memo
json.payment_for check.payment_for
json.status check.is_a?(IncreaseCheck) ? check.state_text.parameterize(separator: "_") : nil # TODO: handle statuses for old Lob checks

json.sender do
  if check.try(:creator) || check.try(:user)
    json.partial! "api/v4/users/user", user: check.try(:creator) || check.try(:user)
  else
    json.nil!
  end
end
