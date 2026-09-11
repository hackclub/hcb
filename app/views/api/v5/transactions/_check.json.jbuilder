# frozen_string_literal: true

# locals: (json:, check:)

increase = check.is_a?(IncreaseCheck)

object_shape(json, check) do |f|
  f.amount_cents check.amount
  f.status { increase ? check.state_text.parameterize(separator: "_") : nil }
  f.memo check.memo
  f.payment_for check.payment_for
  f.check_number { check.check_number }
  f.recipient_name { increase ? check.recipient_name : nil }
  f.recipient_email { increase ? check.recipient_email : nil }
  f.address_line1 { increase ? check.address_line1 : nil }
  f.address_line2 { increase ? check.address_line2 : nil }
  f.address_city { increase ? check.address_city : nil }
  f.address_state { increase ? check.address_state : nil }
  f.address_zip { increase ? check.address_zip : nil }
end
