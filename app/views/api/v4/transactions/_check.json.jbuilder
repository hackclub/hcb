json.address_city check.is_a?(IncreaseCheck) ? check.address_city : nil
json.address_line1 check.is_a?(IncreaseCheck) ? check.address_line1 : nil
json.address_line2 check.is_a?(IncreaseCheck) ? check.address_line2 : nil
json.address_state check.is_a?(IncreaseCheck) ? check.address_state : nil
json.address_zip check.is_a?(IncreaseCheck) ? check.address_zip : nil
json.recipient_name check.is_a?(IncreaseCheck) ? check.recipient_name : nil
json.recipient_email check.is_a?(IncreaseCheck) ? check.recipient_email : nil
json.memo check.memo
json.payment_for check.payment_for
json.check_number check.check_number
json.status check.is_a?(IncreaseCheck) ? check.state_text.parameterize(separator: "_") : nil # TODO: handle statuses for old Lob checks

json.sender do
  if check.try(:creator) || check.try(:user)
    json.partial! "api/v4/users/user", user: check.try(:creator) || check.try(:user)
  else
    json.nil!
  end
end
